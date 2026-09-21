import Foundation

/// Player intent only. Unlisted waves are left to the engine's automatic start.
/// Timing here is a player's deliberate wait after seeing the call button,
/// never a calculation of the engine's reveal time, deadline or reward.
public struct EarlyWaveStrategy: Codable, Equatable, Sendable {
    public enum Policy: Codable, Equatable, Sendable {
        case automatic
        case afterVisible(seconds: Double)
        case whenCountdownAtMost(seconds: Int)
        case whenEnemiesAtMost(count: Int, holdSeconds: Double)
    }

    public struct Decision: Codable, Equatable, Sendable {
        public var wave: Int
        public var policy: Policy
        public init(wave: Int, policy: Policy) { self.wave = wave; self.policy = policy }
    }

    public var decisions: [Decision]
    public init(decisions: [Decision]) { self.decisions = decisions.sorted { $0.wave < $1.wave } }
    public static let automatic = Self(decisions: [])

    public func policy(for wave: Int) -> Policy {
        decisions.first { $0.wave == wave }?.policy ?? .automatic
    }

    public func validate(waveCount: Int) throws {
        guard Set(decisions.map(\.wave)).count == decisions.count else {
            throw DbError.Db(message: "early-wave strategy: duplicate wave decision")
        }
        for decision in decisions {
            guard decision.wave >= 2, decision.wave <= waveCount else {
                throw DbError.Db(message: "early-wave strategy: invalid wave \(decision.wave)")
            }
            switch decision.policy {
            case .automatic: break
            case let .afterVisible(seconds):
                guard seconds.isFinite, seconds >= 0 else {
                    throw DbError.Db(message: "early-wave strategy: invalid delay for wave \(decision.wave)")
                }
            case let .whenCountdownAtMost(seconds):
                guard seconds >= 1 else {
                    throw DbError.Db(message: "early-wave strategy: invalid countdown preference for wave \(decision.wave)")
                }
            case let .whenEnemiesAtMost(count, holdSeconds):
                guard count >= 0, holdSeconds.isFinite, holdSeconds >= 0 else {
                    throw DbError.Db(message: "early-wave strategy: invalid enemy preference or delay for wave \(decision.wave)")
                }
            }
        }
    }

    /// Search choices, not game balance or eligibility constants.
    private static func randomPolicy(rng: inout SeededRNG) -> Policy {
        let delays = [0.0, 1, 3, 6, 10]
        switch Int.random(in: 0..<4, using: &rng) {
        case 0: return .automatic
        case 1: return .afterVisible(seconds: delays.randomElement(using: &rng)!)
        case 2: return .whenCountdownAtMost(seconds: [1, 3, 6, 10].randomElement(using: &rng)!)
        default: return .whenEnemiesAtMost(count: [0, 2, 5, 10, 20].randomElement(using: &rng)!,
                                          holdSeconds: delays.randomElement(using: &rng)!)
        }
    }

    public static func random(waveCount: Int, rng: inout SeededRNG) -> Self {
        guard waveCount > 1 else { return .automatic }
        let common = randomPolicy(rng: &rng), uniform = Bool.random(using: &rng)
        return Self(decisions: (2...waveCount).map {
            Decision(wave: $0, policy: uniform ? common : randomPolicy(rng: &rng))
        })
    }

    public mutating func mutate(waveCount: Int, rng: inout SeededRNG) {
        guard waveCount > 1 else { return }
        let wave = Int.random(in: 2...waveCount, using: &rng)
        decisions.removeAll { $0.wave == wave }
        decisions.append(Decision(wave: wave, policy: Self.randomPolicy(rng: &rng)))
        decisions.sort { $0.wave < $1.wave }
    }

    public static func crossover(_ a: Self, _ b: Self, rng: inout SeededRNG) -> Self {
        let waves = Set(a.decisions.map(\.wave) + b.decisions.map(\.wave)).sorted()
        return Self(decisions: waves.map { wave in
            Decision(wave: wave, policy: (Bool.random(using: &rng) ? a : b).policy(for: wave))
        })
    }
}

/// Reads visible game state and chooses an input. No wave schedule or reward.
public struct EarlyWaveCommander {
    public let strategy: EarlyWaveStrategy
    private var offeredWave: Int?
    private var visibleSince: Double?
    public init(_ strategy: EarlyWaveStrategy) { self.strategy = strategy }

    @MainActor public mutating func tick(sim: GameSimulation) throws {
        guard sim.currentWave > 0, sim.canStartWave else {
            offeredWave = nil; visibleSince = nil; return
        }
        let wave = sim.nextWaveNumber
        if offeredWave != wave { offeredWave = wave; visibleSince = sim.time }
        let wait = sim.time - visibleSince!
        switch strategy.policy(for: wave) {
        case .automatic: return
        case let .afterVisible(seconds):
            guard wait >= seconds else { return }
        case let .whenCountdownAtMost(seconds):
            guard let remaining = sim.waveCountdownSeconds, remaining <= seconds else { return }
        case let .whenEnemiesAtMost(count, holdSeconds):
            guard wait >= holdSeconds, sim.enemies.count <= count else { return }
        }
        guard sim.perform(.startWave) == .ok else {
            throw DbError.Db(message: "Engine rejected visible early-wave control for wave \(wave)")
        }
        offeredWave = nil; visibleSince = nil
    }
}
