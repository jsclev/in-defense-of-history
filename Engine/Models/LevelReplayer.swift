import Foundation

/// Read-only movie source. It only queries recorded actions and resolves their
/// saved presentation. No commander, BattleEngine instance, combat tick or RNG.
final class LevelReplayer {
    let run: LevelRunRecord
    let setup: LevelReplaySetup
    private let dao: LevelRunDAO
    private var page: [LevelActionRecord] = []
    private var pageIndex = 0
    private var queryCursor: Int64 = -1
    private var consumedSequence: Int64 = -1
    private var buffered: LevelActionRecord?
    private(set) var frame: LevelReplayFrame?
    private(set) var actions: [LevelActionRecord] = []
    private(set) var isFinished = false
    private(set) var playSpeedOverride: PlaySpeed?
    private var recordedSpeed: PlaySpeed
    private var compact: Bool?
    private var timeline: ReplayTimelineReader?
    private var eventIndex = 0
    private var eventSequence: Int64 = 0
    private var leadingEvents: [LevelActionRecord] = []
    var playSpeed: PlaySpeed { playSpeedOverride ?? recordedSpeed }
    var frameWallSeconds: Double { 1 / (Double(setup.ticksPerSecond) * playSpeed.factor) }

    func setPlaySpeedOverride(_ speed: PlaySpeed?) { playSpeedOverride = speed }

    init(dao: LevelRunDAO, runID: UUID, playSpeedOverride: PlaySpeed? = nil) throws {
        self.dao = dao
        self.playSpeedOverride = playSpeedOverride
        run = try dao.get(id: runID)
        recordedSpeed = run.playSpeed
        guard run.status != .running else { throw DbError.Db(message: "level_run[\(runID)]: recording is still running") }
        setup = try LevelRecordingCodec.decode(LevelReplaySetup.self, from: run.setup)
        guard setup.level.id == run.levelID, setup.ticksPerSecond > 0, setup.playSpeed == run.playSpeed else {
            throw DbError.Db(message: "level_run[\(runID)]: invalid setup")
        }
        _ = try setup.roadSurface()
    }

    private func read() throws -> LevelActionRecord? {
        if let buffered { self.buffered = nil; return buffered }
        if pageIndex == page.count {
            page = try dao.actions(runID: run.id, after: queryCursor, limit: compact == true ? 1 : 128)
            pageIndex = 0
            if let last = page.last { queryCursor = last.sequence }
        }
        guard pageIndex < page.count else {
            guard consumedSequence == run.lastSequence else {
                throw DbError.Db(message: "level_run[\(run.id)]: truncated action log")
            }
            return nil
        }
        let row = page[pageIndex]; pageIndex += 1
        guard row.sequence == consumedSequence + 1 else {
            throw DbError.Db(message: "level_run[\(run.id)]: missing action after \(consumedSequence)")
        }
        consumedSequence = row.sequence
        return row
    }

    /// Coalesce multiple inputs at one tick into the final visible state. Every
    /// action is still exposed, in order; no frame depends on rendering speed.
    @discardableResult func advance() throws -> Bool {
        if compact == nil {
            let encoding = try dao.presentationEncoding(runID: run.id)
            guard encoding == "frame" || encoding == LevelReplayTimeline.rowName else {
                throw DbError.Db(message: "level_run[\(run.id)]: unsupported presentation encoding \(encoding)")
            }
            compact = encoding == LevelReplayTimeline.rowName
        }
        return try compact! ? advanceTimeline() : advanceLegacyFrames()
    }

    private func advanceTimeline() throws -> Bool {
        guard !isFinished else { return false }
        let tick = frame.map { $0.tick + 1 } ?? 0
        if timeline == nil || tick > timeline!.timeline.lastTick {
            timeline = nil
            while let row = try read() {
                if row.category != "presentation" {
                    guard frame == nil, row.tick == 0, row.category == "lifecycle", row.name == "started" else {
                        throw DbError.Db(message: "level_run[\(run.id)]: unexpected action outside timeline")
                    }
                    leadingEvents.append(row)
                    continue
                }
                guard row.name == LevelReplayTimeline.rowName, let data = row.presentation else {
                    throw DbError.Db(message: "level_run[\(run.id)]: missing timeline block")
                }
                let decoded = try LevelRecordingCodec.decode(LevelReplayTimeline.self, from: data)
                guard decoded.firstTick == tick, decoded.lastTick == row.tick else {
                    throw DbError.Db(message: "level_run[\(run.id)]: missing or overlapping virtual-time block")
                }
                timeline = try ReplayTimelineReader(decoded); eventIndex = 0
                break
            }
        }
        guard let timeline else { throw DbError.Db(message: "level_run[\(run.id)]: truncated timeline") }
        actions = leadingEvents; leadingEvents.removeAll()
        if eventSequence == 0 { eventSequence = Int64(actions.count) }
        let events = timeline.timeline.events
        while eventIndex < events.count, events[eventIndex].tick == tick {
            let event = events[eventIndex]
            actions.append(LevelActionRecord(runID: run.id, sequence: eventSequence, tick: tick,
                category: event.category, name: event.name, payloadJSON: event.payload, presentation: nil))
            eventIndex += 1; eventSequence += 1
        }
        let nextFrame = try timeline.frame(at: tick)
        recordedSpeed = try PlaySpeed(nextFrame.speed)
        frame = nextFrame
        if tick == run.lastTick {
            guard tick == timeline.timeline.lastTick, eventIndex == events.count, try read() == nil else {
                throw DbError.Db(message: "level_run[\(run.id)]: incorrect final timeline tick")
            }
            isFinished = true
        }
        return true
    }

    private func advanceLegacyFrames() throws -> Bool {
        guard !isFinished else { return false }
        actions.removeAll(keepingCapacity: true)
        guard let first = try read() else { isFinished = true; return false }
        let tick = first.tick
        if let frame, tick != frame.tick + 1 {
            throw DbError.Db(message: "level_run[\(run.id)]: missing presentation tick after \(frame.tick)")
        }
        var nextFrame: LevelReplayFrame?
        var row: LevelActionRecord? = first
        while let action = row {
            if action.tick != tick { buffered = action; break }
            actions.append(action)
            if action.category == "presentation" {
                guard let data = action.presentation else { throw DbError.Db(message: "level_action: missing presentation") }
                let decoded = try LevelRecordingCodec.decode(LevelReplayFrame.self, from: data)
                _ = try PlaySpeed(decoded.speed)
                guard decoded.tick == tick else { throw DbError.Db(message: "level_action: presentation tick mismatch") }
                nextFrame = decoded
            }
            row = try read()
        }
        guard let nextFrame else { throw DbError.Db(message: "level_run[\(run.id)]: tick \(tick) has no presentation") }
        recordedSpeed = try PlaySpeed(nextFrame.speed)
        frame = nextFrame
        if row == nil {
            guard tick == run.lastTick else { throw DbError.Db(message: "level_run[\(run.id)]: incorrect final tick") }
            isFinished = true
        }
        return true
    }
}

/// Resample recorded game-time frames to a fixed movie frame rate. Fast playback
/// consumes every source action but samples fewer visible poses; slow playback
/// holds poses longer. Encoding speed never affects the resulting movie time.
struct LevelReplayTiming {
    let framesPerSecond: Int
    private(set) var wallSeconds: Double = 0
    private(set) var outputFrames: Int = 0

    init(framesPerSecond: Int) {
        precondition(framesPerSecond > 0)
        self.framesPerSecond = framesPerSecond
    }

    mutating func append(gameSeconds: Double, speed: PlaySpeed) -> Range<Int> {
        precondition(gameSeconds.isFinite && gameSeconds > 0)
        wallSeconds += gameSeconds / speed.factor
        let first = outputFrames
        outputFrames = max(1, Int(ceil(wallSeconds * Double(framesPerSecond) - 1e-9)))
        return first..<outputFrames
    }
}
