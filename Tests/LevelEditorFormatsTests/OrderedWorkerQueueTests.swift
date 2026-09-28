import XCTest
@testable import LevelEditorFormats

final class OrderedWorkerQueueTests: XCTestCase {
    @MainActor private final class Transport {
        let pipes: [Pipe]
        var readers: [WorkerReplyReader]
        var descriptors: [Int32] { pipes.map { $0.fileHandleForReading.fileDescriptor } }
        init(_ count: Int) {
            pipes = (0..<count).map { _ in Pipe() }
            readers = (0..<count).map { _ in WorkerReplyReader() }
        }
        func write(_ text: String, to worker: Int) throws {
            try pipes[worker].fileHandleForWriting.write(contentsOf: Data(text.utf8))
        }
        func read(_ worker: Int) throws -> Data? {
            try readers[worker].readAvailable(from: pipes[worker].fileHandleForReading.fileDescriptor)
        }
        func disconnect(_ worker: Int) {
            try? pipes[worker].fileHandleForReading.close()
            try? pipes[worker].fileHandleForWriting.close()
        }
        func close() { for worker in pipes.indices { disconnect(worker) } }
    }

    @MainActor func testFastWorkerRefillsBeforeSlowPartialReplyAndResultsStayOrdered() throws {
        let transport = Transport(2)
        defer { transport.close() }
        let releaseSlow = DispatchSemaphore(value: 0)
        let writer = DispatchGroup()
        var finished: [Int] = []
        var assignments: [(worker: Int, job: Int)] = []
        let results: [Int] = try OrderedWorkerQueue.run(jobCount: 7, descriptors: transport.descriptors,
            send: { worker, job in
                assignments.append((worker, job))
                if job == 0 {
                    try transport.write("0", to: worker)
                    let handle = transport.pipes[worker].fileHandleForWriting
                    writer.enter()
                    DispatchQueue.global().async {
                        // The timeout makes a barrier regression fail an
                        // assertion instead of hanging the test process.
                        _ = releaseSlow.wait(timeout: .now() + 2)
                        try? handle.write(contentsOf: Data("\n".utf8))
                        writer.leave()
                    }
                } else {
                    if job == 2 {
                        XCTAssertEqual(worker, 1, "the newly free worker should receive the next job")
                        XCTAssertFalse(finished.contains(0), "refill must not wait for the slow worker")
                        releaseSlow.signal()
                    }
                    try transport.write("\(job)\n", to: worker)
                }
            }, receive: { worker, job in
                guard let line = try transport.read(worker) else { return nil }
                let result = try XCTUnwrap(Int(String(decoding: line, as: UTF8.self)))
                XCTAssertEqual(result, job)
                finished.append(result)
                return result
            }, disconnect: { worker in transport.disconnect(worker) })
        XCTAssertEqual(writer.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(results, Array(0..<7))
        XCTAssertEqual(finished.first, 1)
        XCTAssertEqual(assignments.map(\.job), Array(0..<7), "every job must run exactly once")
    }

    @MainActor func testFailureStopsAdmissionAndDrainsLargeHealthyReply() throws {
        let transport = Transport(2)
        defer { transport.close() }
        let payload = Data(repeating: 65, count: 1024 * 1024)
        let writer = DispatchGroup()
        var sent: [Int] = []
        var drained = false
        var disconnected: [Int] = []
        XCTAssertThrowsError(try OrderedWorkerQueue.run(jobCount: 10, descriptors: transport.descriptors,
            send: { worker, job in
                sent.append(job)
                if job == 0 { try transport.write("failed\n", to: worker) }
                else {
                    let handle = transport.pipes[worker].fileHandleForWriting
                    writer.enter()
                    DispatchQueue.global().async {
                        try? handle.write(contentsOf: payload + Data("\n".utf8))
                        writer.leave()
                    }
                }
            }, receive: { worker, job -> Int? in
                guard let line = try transport.read(worker) else { return nil }
                if job == 0 { throw DbError.Db(message: "deliberate failed battle") }
                XCTAssertEqual(line, payload)
                drained = true
                return job
            }, disconnect: { worker in
                disconnected.append(worker)
                transport.disconnect(worker)
            })) { error in
                XCTAssertTrue(String(describing: error).contains("deliberate failed battle"))
            }
        XCTAssertEqual(writer.wait(timeout: .now() + 2), .success)
        XCTAssertTrue(drained, "healthy writers must drain before process shutdown")
        XCTAssertEqual(sent, [0, 1], "no new battles may start after an observed failure")
        XCTAssertEqual(disconnected, [0])
    }

    @MainActor func testSendFailureDrainsPreviouslyDispatchedWork() throws {
        let transport = Transport(3)
        defer { transport.close() }
        var sent: [Int] = []
        var received: [Int] = []
        XCTAssertThrowsError(try OrderedWorkerQueue.run(jobCount: 6, descriptors: transport.descriptors,
            send: { worker, job in
                sent.append(job)
                if job == 1 { throw DbError.Db(message: "failed request write") }
                try transport.write("\(job)\n", to: worker)
            }, receive: { worker, job -> Int? in
                guard try transport.read(worker) != nil else { return nil }
                received.append(job)
                return job
            }, disconnect: { transport.disconnect($0) }))
        XCTAssertEqual(sent, [0, 1])
        XCTAssertEqual(received, [0])
    }

    @MainActor func testClosedPipeFailsWithoutDroppingOtherResults() throws {
        let transport = Transport(2)
        defer { transport.close() }
        var received: [Int] = []
        XCTAssertThrowsError(try OrderedWorkerQueue.run(jobCount: 3, descriptors: transport.descriptors,
            send: { worker, job in
                if job == 0 { try transport.pipes[worker].fileHandleForWriting.close() }
                else { try transport.write("\(job)\n", to: worker) }
            }, receive: { worker, job -> Int? in
                guard try transport.read(worker) != nil else { return nil }
                received.append(job)
                return job
            }, disconnect: { transport.disconnect($0) }))
        XCTAssertEqual(received, [1])
    }

    @MainActor func testEmptyAndShortQueuesDoNotDispatchExtraWork() throws {
        let empty: [Int] = try OrderedWorkerQueue.run(jobCount: 0, descriptors: [],
            send: { _, _ in XCTFail("empty queue dispatched") },
            receive: { _, _ in XCTFail("empty queue received"); return nil }, disconnect: { _ in })
        XCTAssertTrue(empty.isEmpty)
        let transport = Transport(4)
        defer { transport.close() }
        var sent: [Int] = []
        let results: [Int] = try OrderedWorkerQueue.run(jobCount: 2, descriptors: transport.descriptors,
            send: { worker, job in sent.append(job); try transport.write("\(job)\n", to: worker) },
            receive: { worker, job in try transport.read(worker) == nil ? nil : job },
            disconnect: { transport.disconnect($0) })
        XCTAssertEqual(sent, [0, 1])
        XCTAssertEqual(results, [0, 1])
    }
}
