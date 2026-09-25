import Foundation
import Combine

/// Interactive playback of saved poses. Wall time only chooses the virtual tick;
/// this controller never runs gameplay or writes to the recorded attempt.
@MainActor
final class LevelReplayPlayback: ObservableObject {
    private let replay: LevelReplayer
    private var pendingSeconds: Double = 0
    @Published private(set) var frame: LevelReplayFrame
    @Published private(set) var isPaused = false
    @Published private(set) var isFinished: Bool

    var setup: LevelReplaySetup { replay.setup }

    init(dao: LevelRunDAO, runID: UUID, speed: PlaySpeed) throws {
        replay = try LevelReplayer(dao: dao, runID: runID, playSpeedOverride: speed)
        guard try replay.advance(), let first = replay.frame else {
            throw DbError.Db(message: "level_run[\(runID)]: missing initial replay frame")
        }
        frame = first
        isFinished = replay.isFinished
    }

    func togglePause() {
        guard !isFinished else { return }
        isPaused.toggle()
    }

    func advance(wallSeconds: Double) throws {
        guard !isPaused, !isFinished else { return }
        precondition(wallSeconds.isFinite && wallSeconds >= 0)
        pendingSeconds += wallSeconds
        while pendingSeconds + 1e-12 >= replay.frameWallSeconds {
            pendingSeconds = max(0, pendingSeconds - replay.frameWallSeconds)
            guard try replay.advance(), let next = replay.frame else {
                throw DbError.Db(message: "level_run[\(replay.run.id)]: replay ended before its final tick")
            }
            frame = next
            if replay.isFinished {
                isFinished = true
                pendingSeconds = 0
                break
            }
        }
    }
}
