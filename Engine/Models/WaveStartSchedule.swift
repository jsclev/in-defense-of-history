import Foundation

/// Interactive wave timing, advanced only by the runner's game clock.
/// Enemy lifetime is deliberately independent: multiple waves may be alive.
public struct WaveStartSchedule {
    public enum State: Equatable {
        case finished
        case manualFirstWave
        case hidden
        case countingDown(seconds: Int)
        case due

        public var canCall: Bool {
            switch self {
            case .manualFirstWave, .countingDown: return true
            default: return false
            }
        }
    }

    private struct Entry {
        let callButtonDelay: Double
        let autoStartCountdown: Double
        let earlyCallBonus: Int
    }

    private let entries: [Entry]
    public private(set) var nextWaveIndex = 0
    private var previousStartTick: Int64 = 0

    public init() { entries = [] }

    /// Interactive levels require authored timing for every wave. Missing or
    /// invalid data is an error, never a hardcoded gameplay fallback.
    public init(waves: [Wave]) throws {
        entries = try waves.enumerated().map { index, wave in
            guard let delay = wave.callButtonDelay, delay.isFinite, delay >= 0,
                  let countdown = wave.autoStartCountdown, countdown.isFinite, countdown >= 0 else {
                throw DbError.Db(message: "Wave \(index + 1) is missing valid database start timing.")
            }
            guard let bonus = wave.earlyCallBonus, bonus >= 0 else {
                throw DbError.Db(message: "Wave \(index + 1) is missing a valid database early-call bonus.")
            }
            return Entry(callButtonDelay: delay, autoStartCountdown: countdown, earlyCallBonus: bonus)
        }
    }

    public var allWavesStarted: Bool { nextWaveIndex >= entries.count }

    public func state(at tick: Int64) -> State {
        guard !allWavesStarted else { return .finished }
        guard nextWaveIndex > 0 else { return .manualFirstWave }
        let wave = entries[nextWaveIndex]
        let revealTick = previousStartTick + ticks(for: wave.callButtonDelay)
        let startTick = revealTick + ticks(for: wave.autoStartCountdown)
        if tick >= startTick { return .due }
        if tick < revealTick { return .hidden }
        let remaining = Double(startTick - tick) / Double(SimClock.ticksPerSecond)
        return .countingDown(seconds: Int(ceil(remaining)))
    }

    /// Returns the wave and its money reward exactly once. Only manual calls
    /// after wave 1 earn a bonus, and only while the button is visible.
    public mutating func startNextWave(at tick: Int64, manually: Bool) -> (index: Int, moneyBonus: Int)? {
        let state = state(at: tick)
        guard manually ? state.canCall : state == .due else { return nil }
        let index = nextWaveIndex
        let bonus = manually && index > 0 ? entries[index].earlyCallBonus : 0
        nextWaveIndex += 1
        previousStartTick = tick
        return (index, bonus)
    }

    private func ticks(for seconds: Double) -> Int64 {
        Int64((max(0, seconds) * Double(SimClock.ticksPerSecond)).rounded(.up))
    }
}
