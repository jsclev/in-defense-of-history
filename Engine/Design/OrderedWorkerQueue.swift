import Foundation
import Darwin

/// Transport only: keep one request in flight per process, refill whichever
/// process finishes first, and return results in the original request order.
/// Callers own admission limits, generation boundaries and result validation.
@MainActor enum OrderedWorkerQueue {
    static func run<Result>(jobCount: Int, descriptors: [Int32],
                            send: (_ worker: Int, _ job: Int) throws -> Void,
                            receive: (_ worker: Int, _ job: Int) throws -> Result?,
                            disconnect: (_ worker: Int) -> Void) throws -> [Result] {
        guard jobCount > 0 else { return [] }
        guard !descriptors.isEmpty, descriptors.allSatisfy({ $0 >= 0 }),
              Set(descriptors).count == descriptors.count else {
            throw DbError.Db(message: "worker queue requires distinct valid worker pipes")
        }
        var results = [Result?](repeating: nil, count: jobCount)
        var inFlight = [Int?](repeating: nil, count: descriptors.count)
        var next = 0
        var failure: Error?

        func dispatch(_ worker: Int) {
            guard failure == nil, next < jobCount else { return }
            do {
                try send(worker, next)
                inFlight[worker] = next
                next += 1
            } catch {
                failure = error
                // A failed write may have sent a partial request. EOF lets the
                // child exit; closing its output prevents a blocked reply.
                disconnect(worker)
            }
        }
        for worker in descriptors.indices { dispatch(worker) }

        while inFlight.contains(where: { $0 != nil }) {
            var pollers = descriptors.indices.map { worker in
                pollfd(fd: inFlight[worker] == nil ? -1 : descriptors[worker],
                       events: Int16(POLLIN), revents: 0)
            }
            let ready = pollers.withUnsafeMutableBufferPointer {
                Darwin.poll($0.baseAddress, nfds_t($0.count), -1)
            }
            if ready < 0 {
                if errno == EINTR { continue }
                let code = errno
                for worker in descriptors.indices where inFlight[worker] != nil { disconnect(worker) }
                throw failure ?? DbError.Db(message: "worker queue poll failed: errno \(code)")
            }
            for worker in descriptors.indices where pollers[worker].revents != 0 {
                guard let job = inFlight[worker] else { continue }
                do {
                    guard pollers[worker].revents & Int16(POLLNVAL) == 0 else {
                        throw DbError.Db(message: "worker queue received an invalid pipe")
                    }
                    // Read only currently available bytes. A partial large
                    // reply must not block another worker's completed reply.
                    guard let result = try receive(worker, job) else { continue }
                    results[job] = result
                    inFlight[worker] = nil
                    dispatch(worker)
                } catch {
                    if failure == nil { failure = error }
                    inFlight[worker] = nil
                    disconnect(worker)
                }
            }
            // After the first failure, dispatch stops but all healthy in-flight
            // replies are drained before the caller waits for process exit.
        }
        if let failure { throw failure }
        return try results.enumerated().map { index, result in
            guard let result else { throw DbError.Db(message: "worker queue is missing result \(index)") }
            return result
        }
    }
}

/// Newline-delimited replies, consumed incrementally after poll reports data.
/// Startup can call this repeatedly to wait for its one handshake reply.
struct WorkerReplyReader {
    private var buffered = Data()
    private let maximumBytes = 16 * 1024 * 1024

    mutating func readAvailable(from descriptor: Int32) throws -> Data? {
        var bytes = [UInt8](repeating: 0, count: 65_536)
        let count: Int
        while true {
            let received = Darwin.read(descriptor, &bytes, bytes.count)
            if received < 0, errno == EINTR { continue }
            count = received
            break
        }
        guard count > 0 else {
            throw DbError.Db(message: "genetic worker closed its response pipe or failed to read; inspect stderr")
        }
        guard buffered.count + count <= maximumBytes else {
            throw DbError.Db(message: "genetic worker sent an oversized response; inspect stderr")
        }
        buffered.append(contentsOf: bytes.prefix(count))
        guard let newline = buffered.firstIndex(of: 10) else { return nil }
        // There is exactly one response per in-flight request. Extra bytes
        // would be an unsolicited reply, not another scheduled result.
        guard buffered.index(after: newline) == buffered.endIndex else {
            throw DbError.Db(message: "genetic worker sent unsolicited response data")
        }
        let line = Data(buffered[..<newline])
        buffered.removeAll(keepingCapacity: true)
        return line
    }
}
