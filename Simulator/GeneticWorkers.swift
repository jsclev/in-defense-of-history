import Foundation
import CryptoKit
import Darwin
import OSLog

/// Process isolation gives each battle its own main actor. This transport owns
/// no game rules: workers call the same commander and DAOs as serial evaluation.
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
        SimulatorLog.worker.info("Worker starting; pid=\(ProcessInfo.processInfo.processIdentifier)")
        let store = try SimulatorStore(existing: URL(fileURLWithPath: path))
        defer { store.db.close() }
        let db = store.db
        let configuration = try GeneticStudyDAO(db: db).workerConfiguration()
        let executable = try Data(contentsOf: SimulatorStore.executableURL)
        guard SHA256.hash(data: executable).map({ String(format: "%02x", $0) }).joined() == configuration.executableSHA256 else {
            throw DbError.Db(message: "genetic worker: executable changed during startup")
        }
        try configuration.heroLoadout.validate()
        let copy = try BountyExperimentDAO.contentCopy(of: db, fraction: configuration.bountyFraction,
            selectedHeroIDs: configuration.heroLoadout.selectedHeroIDs,
            heroAI: Dictionary(uniqueKeysWithValues: configuration.heroLoadout.deployments.map { ($0.heroID, $0.aiEnabled) }))
        defer { copy.close() }
        let study = try AuthoredMoneyStudy(db: copy, levelID: configuration.levelID)
        let snapshot = try study.replaySnapshot(db: db, heroesEnabled: true)
        let digest = SHA256.hash(data: snapshot).map { String(format: "%02x", $0) }.joined()
        guard digest == configuration.contentSHA256,
              configuration.heroLoadout == (try GeneticHeroLoadout(content: study.battle)) else {
            throw DbError.Db(message: "genetic worker: authored content changed during startup")
        }
        SimulatorLog.worker.notice("Worker ready; runID=\(configuration.runID.uuidString, privacy: .public) levelID=\(configuration.levelID.uuidString, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier)")
        let decoder = MetaUpgradesFactory.decoder(catalog: study.battle.playerUpgrades.loadout.catalog)
        var selections: [Set<MetaUpgrade>: AuthoredMoneyStudy] = [study.battle.playerUpgrades.loadout.selected: study]
        func reply(_ value: GeneticWorkerReply) throws {
            var data = try JSONEncoder().encode(value); data.append(10)
            try FileHandle.standardOutput.write(contentsOf: data)
        }
        try reply(GeneticWorkerReply(index: -1, evaluation: nil, error: nil))
        var completedJobs = 0
        while let line = readLine() {
            try autoreleasepool {
                let request = try decoder.decode(GeneticWorkerRequest.self, from: Data(line.utf8))
                do {
                    SimulatorLog.worker.debug("Battle started; runID=\(configuration.runID.uuidString, privacy: .public) job=\(request.index) seed=\(request.job.seed) stars=\(request.job.strategy.metaProgression.spentStars)")
                    let selection = Set(request.job.strategy.metaUpgrades)
                    if selections[selection] == nil { selections[selection] = try study.selectingMetaUpgrades(selection) }
                    let selected = selections[selection]!
                    try request.job.strategy.validate(study: selected)
                    let result = try GeneticCommander.evaluate(request.job.strategy,
                        recording: .evaluation, content: selected.battle,
                        money: configuration.money, seed: request.job.seed, maxSeconds: configuration.maxSeconds)
                    completedJobs += 1
                    SimulatorLog.worker.debug("Battle completed; runID=\(configuration.runID.uuidString, privacy: .public) job=\(request.index) seed=\(request.job.seed) outcome=\(String(describing: result.result.outcome), privacy: .public) seconds=\(result.result.seconds)")
                    try reply(GeneticWorkerReply(index: request.index, evaluation: result, error: nil))
                } catch {
                    SimulatorLog.worker.error("Battle failed; runID=\(configuration.runID.uuidString, privacy: .public) job=\(request.index) seed=\(request.job.seed) detail=\(String(describing: error), privacy: .private)")
                    try reply(GeneticWorkerReply(index: request.index, evaluation: nil, error: String(describing: error)))
                    throw error
                }
            }
        }
        SimulatorLog.worker.notice("Worker stopped after input closed; runID=\(configuration.runID.uuidString, privacy: .public) completedJobs=\(completedJobs)")
    }
}

@MainActor final class GeneticWorkerPool {
    private final class Worker {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        var reader = WorkerReplyReader()
        var descriptor: Int32 { output.fileHandleForReading.fileDescriptor }

        init(configuration: URL) throws {
            process.executableURL = try SimulatorStore.executableURL
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
                if let reply = try receiveAvailable() { return reply }
            }
        }
        func receiveAvailable() throws -> GeneticWorkerReply? {
            guard let line = try reader.readAvailable(from: descriptor) else { return nil }
            return try JSONDecoder().decode(GeneticWorkerReply.self, from: line)
        }
        func send(_ request: GeneticWorkerRequest) throws {
            var data = try JSONEncoder().encode(request); data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func disconnect() {
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
        }
        func close() {
            try? input.fileHandleForWriting.close()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                SimulatorLog.worker.error("Worker exited unsuccessfully; pid=\(self.process.processIdentifier) status=\(self.process.terminationStatus)")
            }
            try? output.fileHandleForReading.close()
        }
    }
    private let runID: UUID
    private var workers: [Worker] = []

    init(count: Int, configuration: GeneticWorkerConfiguration, db: Db) throws {
        runID = configuration.runID
        SimulatorLog.worker.notice("Starting worker pool; runID=\(configuration.runID.uuidString, privacy: .public) workers=\(count)")
        // Convert a closed worker pipe into a reported I/O failure, never a
        // silent coordinator exit. No worker is retried or forcibly killed.
        signal(SIGPIPE, SIG_IGN)
        let path = URL(fileURLWithPath: db.path)
        // Workers read the immutable relational study configuration.
        do {
            for _ in 0..<count {
                let worker = try Worker(configuration: path)
                workers.append(worker)
                let ready = try worker.receive()
                guard ready.index == -1, ready.error == nil, ready.evaluation == nil else {
                    throw DbError.Db(message: "genetic worker failed its content handshake")
                }
                SimulatorLog.worker.info("Worker handshake accepted; runID=\(configuration.runID.uuidString, privacy: .public) pid=\(worker.process.processIdentifier)")
            }
        } catch {
            SimulatorLog.worker.error("Worker pool startup failed; runID=\(configuration.runID.uuidString, privacy: .public) detail=\(String(describing: error), privacy: .private)")
            close(); throw error
        }
    }

    /// Bound in-flight work and return in request order, independent of which
    /// process finishes first. Breeding and scoring therefore stay deterministic.
    func evaluate(_ jobs: [GeneticBattleJob]) throws -> [GeneticEvaluation] {
        SimulatorLog.worker.debug("Dispatching battle queue; runID=\(self.runID.uuidString, privacy: .public) jobs=\(jobs.count) workers=\(self.workers.count)")
        do {
            return try OrderedWorkerQueue.run(jobCount: jobs.count, descriptors: workers.map(\.descriptor),
                send: { worker, index in
                    try workers[worker].send(GeneticWorkerRequest(index: index, job: jobs[index]))
                }, receive: { worker, index in
                    guard let reply = try workers[worker].receiveAvailable() else { return nil }
                    guard reply.index == index, reply.error == nil, let evaluation = reply.evaluation,
                          evaluation.seed == jobs[index].seed else {
                        throw DbError.Db(message: "genetic worker evaluation failed: \(reply.error ?? "invalid response")")
                    }
                    return evaluation
                }, disconnect: { worker in workers[worker].disconnect() })
        } catch {
            SimulatorLog.worker.error("Worker queue failed; runID=\(self.runID.uuidString, privacy: .public) detail=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    func close() {
        guard !workers.isEmpty else { return }
        for worker in workers { worker.close() }
        SimulatorLog.worker.info("Worker pool closed; runID=\(self.runID.uuidString, privacy: .public) workers=\(self.workers.count)")
        workers.removeAll()
    }
}
