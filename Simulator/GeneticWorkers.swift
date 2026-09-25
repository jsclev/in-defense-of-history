import Foundation
import CryptoKit
import Darwin

/// Process isolation gives each battle its own main actor. This transport owns
/// no game rules: workers call the same commander and DAOs as serial evaluation.
struct GeneticWorkerConfiguration: Codable {
    let level: String
    let contentSHA256: String
    let executableSHA256: String
    let bountyFraction: Double
    let money: Int
    let maxSeconds: Double
    let heroLoadout: GeneticHeroLoadout
}

struct GeneticBattleJob: Codable {
    let strategy: GeneticStrategy
    let seed: UInt64
}

private struct GeneticWorkerRequest: Codable {
    let index: Int
    let job: GeneticBattleJob
}

private struct GeneticWorkerReply: Codable {
    let index: Int
    let evaluation: GeneticEvaluation?
    let error: String?
}

@MainActor enum GeneticBattleWorker {
    static func run(configuration path: String) throws {
        let configuration = try JSONDecoder().decode(GeneticWorkerConfiguration.self,
            from: Data(contentsOf: URL(fileURLWithPath: path)))
        let executable = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))
        guard SHA256.hash(data: executable).map({ String(format: "%02x", $0) }).joined() == configuration.executableSHA256 else {
            throw DbError.Db(message: "genetic worker: executable changed during startup")
        }
        let store = try SimulatorStore()
        defer { store.db.close() }
        let db = store.db
        guard let id = try db.levelInfoDao.getIdBy(levelName: configuration.level) else {
            throw DbError.Db(message: "genetic worker: unknown level")
        }
        try configuration.heroLoadout.validate()
        let copy = try BountyExperimentDAO.contentCopy(of: db, fraction: configuration.bountyFraction,
            selectedHeroIDs: configuration.heroLoadout.selectedHeroIDs,
            heroAI: Dictionary(uniqueKeysWithValues: configuration.heroLoadout.deployments.map { ($0.heroID, $0.aiEnabled) }))
        defer { copy.close() }
        let study = try AuthoredMoneyStudy(db: copy, levelID: id)
        let snapshot = try study.replaySnapshot(db: db, heroesEnabled: true)
        let digest = SHA256.hash(data: snapshot).map { String(format: "%02x", $0) }.joined()
        guard digest == configuration.contentSHA256,
              configuration.heroLoadout == (try GeneticHeroLoadout(content: study.battle)) else {
            throw DbError.Db(message: "genetic worker: authored content changed during startup")
        }
        var selections: [Set<MetaUpgrade>: AuthoredMoneyStudy] = [study.battle.playerUpgrades.loadout.selected: study]
        func reply(_ value: GeneticWorkerReply) throws {
            var data = try JSONEncoder().encode(value); data.append(10)
            try FileHandle.standardOutput.write(contentsOf: data)
        }
        try reply(GeneticWorkerReply(index: -1, evaluation: nil, error: nil))
        while let line = readLine() {
            try autoreleasepool {
                let request = try JSONDecoder().decode(GeneticWorkerRequest.self, from: Data(line.utf8))
                do {
                    let selection = Set(request.job.strategy.metaUpgrades)
                    if selections[selection] == nil { selections[selection] = try study.selectingMetaUpgrades(selection) }
                    let selected = selections[selection]!
                    try request.job.strategy.validate(study: selected)
                    let result = try GeneticCommander.evaluate(request.job.strategy,
                        recording: .database(db.levelRunDao, .simulator), content: selected.battle,
                        money: configuration.money, seed: request.job.seed, maxSeconds: configuration.maxSeconds)
                    try reply(GeneticWorkerReply(index: request.index, evaluation: result, error: nil))
                } catch {
                    try reply(GeneticWorkerReply(index: request.index, evaluation: nil, error: String(describing: error)))
                    throw error
                }
            }
        }
    }
}

@MainActor final class GeneticWorkerPool {
    private final class Worker {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        var buffered = Data()

        init(configuration: URL) throws {
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            process.arguments = ["--genetic-worker", configuration.path]
            process.standardInput = input; process.standardOutput = output
            // Diagnostics cannot corrupt the JSON response stream.
            process.standardError = FileHandle.standardError
            try process.run()
            try input.fileHandleForReading.close()
            try output.fileHandleForWriting.close()
        }
        func receive() throws -> GeneticWorkerReply {
            while true {
                if let newline = buffered.firstIndex(of: 10) {
                    let line = buffered[..<newline]
                    let reply = try JSONDecoder().decode(GeneticWorkerReply.self, from: line)
                    buffered.removeSubrange(...newline)
                    return reply
                }
                guard buffered.count < 16 * 1024 * 1024 else {
                    throw DbError.Db(message: "genetic worker stopped or sent an invalid response; inspect stderr")
                }
                // FileHandle.read(upToCount:) can wait for the entire requested
                // length on a pipe. POSIX read returns the available bytes so
                // a short ready/result line cannot deadlock both processes.
                var bytes = [UInt8](repeating: 0, count: 65_536)
                let count = Darwin.read(output.fileHandleForReading.fileDescriptor, &bytes, bytes.count)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else {
                    throw DbError.Db(message: "genetic worker closed its response pipe; inspect stderr")
                }
                buffered.append(contentsOf: bytes.prefix(count))
            }
        }
        func send(_ request: GeneticWorkerRequest) throws {
            var data = try JSONEncoder().encode(request); data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func close() {
            try? input.fileHandleForWriting.close()
            process.waitUntilExit()
            try? output.fileHandleForReading.close()
        }
    }
    private var workers: [Worker] = []

    init(count: Int, configuration: GeneticWorkerConfiguration, directory: URL) throws {
        // Convert a closed worker pipe into a reported I/O failure, never a
        // silent coordinator exit. No worker is retried or forcibly killed.
        signal(SIGPIPE, SIG_IGN)
        let path = directory.appendingPathComponent("worker-configuration.json")
        try JSONEncoder().encode(configuration).write(to: path, options: .atomic)
        do {
            for _ in 0..<count {
                let worker = try Worker(configuration: path)
                workers.append(worker)
                let ready = try worker.receive()
                guard ready.index == -1, ready.error == nil, ready.evaluation == nil else {
                    throw DbError.Db(message: "genetic worker failed its content handshake")
                }
            }
        } catch {
            close(); throw error
        }
    }

    /// Bound in-flight work and return in request order, independent of which
    /// process finishes first. Breeding and scoring therefore stay deterministic.
    func evaluate(_ jobs: [GeneticBattleJob]) throws -> [GeneticEvaluation] {
        var results: [GeneticEvaluation] = []
        for start in stride(from: 0, to: jobs.count, by: workers.count) {
            let count = min(workers.count, jobs.count - start)
            var failure: Error?
            var sent = 0
            for offset in 0..<count {
                do {
                    try workers[offset].send(GeneticWorkerRequest(index: start + offset, job: jobs[start + offset]))
                    sent += 1
                } catch { failure = error; break }
            }
            // Drain all replies in this batch before surfacing a failure, so
            // shutdown cannot deadlock a healthy worker writing a large result.
            for offset in 0..<sent {
                do {
                    let reply = try workers[offset].receive()
                    guard reply.index == start + offset, reply.error == nil, let evaluation = reply.evaluation,
                          evaluation.seed == jobs[start + offset].seed else {
                        throw DbError.Db(message: "genetic worker evaluation failed: \(reply.error ?? "invalid response")")
                    }
                    results.append(evaluation)
                } catch { if failure == nil { failure = error } }
            }
            if let failure { throw failure }
        }
        return results
    }

    func close() {
        for worker in workers { worker.close() }
        workers.removeAll()
    }
}
