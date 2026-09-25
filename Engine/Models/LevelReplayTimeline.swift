import Foundation

/// Lossless presentation tracks in virtual ticks. Constant fields are stored
/// once; constant-velocity numeric runs store a start value and an increment.
/// A speed/state change ends the segment. No gameplay or wall clock is involved.
enum ReplayTimelineValue: Codable, Equatable {
    case object([String]), array(Int), text(String), bytes(Data), document(Data)
    case integer(Int64), unsigned(UInt64), real(Double), flag(Bool), null

    static func == (a: Self, b: Self) -> Bool {
        switch (a, b) {
        case let (.object(a), .object(b)): return a == b
        case let (.array(a), .array(b)): return a == b
        case let (.text(a), .text(b)): return a == b
        case let (.bytes(a), .bytes(b)): return a == b
        case let (.document(a), .document(b)): return a == b
        case let (.integer(a), .integer(b)): return a == b
        case let (.unsigned(a), .unsigned(b)): return a == b
        case let (.real(a), .real(b)): return a.bitPattern == b.bitPattern
        case let (.flag(a), .flag(b)): return a == b
        case (.null, .null): return true
        default: return false
        }
    }
}

struct ReplayTimelineSegment: Codable {
    let tick: Int64
    var count: Int
    let value: ReplayTimelineValue
    var increment: Double?

    func value(at tick: Int64) throws -> ReplayTimelineValue {
        guard count > 0, tick >= self.tick, tick - self.tick < Int64(count) else {
            throw DbError.Db(message: "level_action.timeline: missing value at tick \(tick)")
        }
        guard let increment else { return value }
        guard case .real(var number) = value, number.isFinite, increment.isFinite else {
            throw DbError.Db(message: "level_action.timeline: invalid movement segment")
        }
        // Repeated addition preserves the recorded IEEE-754 values exactly.
        // Multiplying by elapsed ticks can introduce a different rounding.
        for _ in 0..<Int(tick - self.tick) { number += increment }
        return .real(number)
    }
}

struct ReplayTimelineTrack: Codable {
    let path: String
    let segments: [ReplayTimelineSegment]
}

struct ReplayTimelineEvent: Codable {
    let tick: Int64
    let category: String
    let name: String
    let payload: String
}

struct LevelReplayTimeline: Codable {
    static let rowName = "timeline-v1"
    let version: Int
    let firstTick: Int64
    let lastTick: Int64
    let tracks: [ReplayTimelineTrack]
    let events: [ReplayTimelineEvent]

    static func child(_ path: String, _ key: String) -> String {
        path + "/" + key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
    }
}

/// Only one bounded block and one pending visible state are retained. Limits
/// are storage packing limits, not a sampling interval: every virtual tick and
/// every event is recoverable, including bends, stops, hits and rejected inputs.
final class ReplayTimelineBuilder {
    static let maximumTicks = 256
    static let maximumSegments = 16_384
    private final class Track {
        let path: String
        var segments: [ReplayTimelineSegment]
        var lastValue: ReplayTimelineValue
        var lastTick: Int64

        init(path: String, value: ReplayTimelineValue, tick: Int64) {
            self.path = path; lastValue = value; lastTick = tick
            segments = [ReplayTimelineSegment(tick: tick, count: 1, value: value)]
        }

        func append(_ value: ReplayTimelineValue, tick: Int64) -> Bool {
            let index = segments.count - 1
            if tick == lastTick + 1 {
                if let increment = segments[index].increment, case .real(let previous) = lastValue,
                   case .real(let next) = value, (previous + increment).bitPattern == next.bitPattern {
                    segments[index].count += 1; lastValue = value; lastTick = tick
                    return false
                }
                if segments[index].increment == nil, lastValue == value {
                    segments[index].count += 1; lastTick = tick
                    return false
                }
                if segments[index].count == 1, case .real(let previous) = lastValue,
                   case .real(let next) = value, previous.isFinite, next.isFinite {
                    let increment = next - previous
                    if increment.isFinite, (previous + increment).bitPattern == next.bitPattern {
                        segments[index].increment = increment; segments[index].count = 2
                        lastValue = value; lastTick = tick
                        return false
                    }
                }
            }
            segments.append(ReplayTimelineSegment(tick: tick, count: 1, value: value))
            lastValue = value; lastTick = tick
            return true
        }
    }
    private var tracks: [Track] = []
    private lazy var encoder = ReplayTimelineEncoder { [unowned self] path in
        // Bind each field to its track once. Subsequent ticks need neither
        // string hashing nor a dictionary mutation for every scalar value.
        guard path != "/tick" else { return { _, _ in } }
        var track: Track?
        return { [unowned self] value, tick in
            if let track {
                if track.append(value, tick: tick) { segmentCount += 1 }
            } else {
                let created = Track(path: path, value: value, tick: tick)
                tracks.append(created); track = created; segmentCount += 1
            }
        }
    }
    private(set) var firstTick: Int64?
    private(set) var lastTick: Int64?
    private(set) var segmentCount = 0
    var isFull: Bool {
        guard let firstTick, let lastTick else { return false }
        return lastTick - firstTick + 1 >= Self.maximumTicks || segmentCount >= Self.maximumSegments
    }

    func append(_ frame: LevelReplayFrame) throws {
        if let lastTick, frame.tick != lastTick + 1 {
            throw DbError.Db(message: "level_action.timeline: nonconsecutive virtual tick \(frame.tick)")
        }
        try autoreleasepool { try encoder.append(frame) }
        if firstTick == nil { firstTick = frame.tick }
        lastTick = frame.tick
    }

    func finish(events: [ReplayTimelineEvent]) throws -> LevelReplayTimeline {
        guard let firstTick, let lastTick else { throw DbError.Db(message: "level_action.timeline: empty block") }
        return LevelReplayTimeline(version: 1, firstTick: firstTick, lastTick: lastTick,
            tracks: tracks.sorted { $0.path < $1.path }.map { ReplayTimelineTrack(path: $0.path, segments: $0.segments) }, events: events)
    }
}

/// Reconstructs recorded values only. It never consults live content or runs
/// combat. A malformed or missing channel is an error, never an invented pose.
final class ReplayTimelineReader {
    let timeline: LevelReplayTimeline
    private var tracks: [String: [ReplayTimelineSegment]] = [:]
    private var cursors: [String: Int] = [:]
    private var lastTick: Int64?
    private var documents: [String: (Data, Any)] = [:]

    init(_ timeline: LevelReplayTimeline) throws {
        guard timeline.version == 1, timeline.firstTick >= 0, timeline.lastTick >= timeline.firstTick,
              timeline.lastTick - timeline.firstTick < ReplayTimelineBuilder.maximumTicks else {
            throw DbError.Db(message: "level_action.timeline: invalid version or bounds")
        }
        self.timeline = timeline
        for track in timeline.tracks {
            guard tracks[track.path] == nil, !track.segments.isEmpty else {
                throw DbError.Db(message: "level_action.timeline: duplicate or empty channel \(track.path)")
            }
            var end = timeline.firstTick - 1
            for segment in track.segments {
                guard segment.tick > end, segment.tick >= timeline.firstTick, segment.count > 0,
                      segment.count <= ReplayTimelineBuilder.maximumTicks,
                      segment.tick <= timeline.lastTick,
                      Int64(segment.count - 1) <= timeline.lastTick - segment.tick else {
                    throw DbError.Db(message: "level_action.timeline: invalid segment \(track.path)")
                }
                _ = try segment.value(at: segment.tick)
                end = segment.tick + Int64(segment.count - 1)
            }
            tracks[track.path] = track.segments
        }
        var eventTick = timeline.firstTick
        for event in timeline.events {
            guard event.tick >= eventTick, event.tick <= timeline.lastTick,
                  ["input", "event", "lifecycle"].contains(event.category), !event.name.isEmpty,
                  let data = event.payload.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                throw DbError.Db(message: "level_action.timeline: invalid event")
            }
            eventTick = event.tick
        }
    }

    func frame(at tick: Int64) throws -> LevelReplayFrame {
        guard tick >= timeline.firstTick, tick <= timeline.lastTick,
              lastTick == nil ? tick == timeline.firstTick : tick == lastTick! + 1 else {
            throw DbError.Db(message: "level_action.timeline: invalid playback tick")
        }
        let frame: LevelReplayFrame = try autoreleasepool {
            let value = try resolve(path: "", tick: tick)
            let bytes = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
            return try PropertyListDecoder().decode(LevelReplayFrame.self, from: bytes)
        }
        guard frame.tick == tick else { throw DbError.Db(message: "level_action.timeline: decoded tick mismatch") }
        lastTick = tick
        return frame
    }

    private func resolve(path: String, tick: Int64) throws -> Any {
        if path == "/tick" { return NSNumber(value: tick) }
        guard let segments = tracks[path] else { throw DbError.Db(message: "level_action.timeline: missing channel \(path)") }
        var index = cursors[path] ?? 0
        while index + 1 < segments.count, segments[index + 1].tick <= tick { index += 1 }
        cursors[path] = index
        switch try segments[index].value(at: tick) {
        case let .object(keys):
            guard Set(keys).count == keys.count else { throw DbError.Db(message: "level_action.timeline: duplicate object key") }
            var dictionary: [String: Any] = [:]
            for key in keys { dictionary[key] = try resolve(path: LevelReplayTimeline.child(path, key), tick: tick) }
            return dictionary
        case let .array(count):
            guard count >= 0, count <= tracks.count else { throw DbError.Db(message: "level_action.timeline: invalid array length") }
            return try (0..<count).map { try resolve(path: LevelReplayTimeline.child(path, String($0)), tick: tick) }
        case let .text(value): return value
        case let .bytes(value): return value
        case let .document(data):
            if let cached = documents[path], cached.0 == data { return cached.1 }
            let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            documents[path] = (data, value)
            return value
        case let .integer(value): return NSNumber(value: value)
        case let .unsigned(value): return NSNumber(value: value)
        case let .real(value): return NSNumber(value: value)
        case let .flag(value): return NSNumber(value: value)
        case .null: return "$null"
        }
    }
}
