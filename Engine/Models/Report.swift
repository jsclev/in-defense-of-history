import Foundation

public struct SimulationResult: Sendable, Codable {
    public struct TypeFates: Sendable, Codable {
        public var killed: Int
        public var routed: Int
        public var captured: Int
        public var leaked: Int
    }

    public var outcome: Outcome
    public var seconds: Double
    public var livesRemaining: Int
    public var goldRemaining: Int
    public var goldEarned: Int
    public var killed: Int
    public var routed: Int
    public var captured: Int
    public var leaked: Int
    public var fatesByTypeID: [UUID: TypeFates]
    public var waveMaxProgress: [Double]
    public var leaksByWave: [Int]
}

public enum Percentile {
    public static func of(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        if sorted.count == 1 { return sorted[0] }
        let rank = (p / 100.0) * Double(sorted.count - 1)
        let lo = Int(rank.rounded(.down))
        let hi = Int(rank.rounded(.up))
        if lo == hi { return sorted[lo] }
        let t = rank - Double(lo)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * t
    }
}

public struct BatchReport: Sendable {
    public var results: [SimulationResult]

    public var runs: Int { results.count }
    public var victories: Int { countOutcome(.victory) }
    public var defeats: Int { countOutcome(.defeat) }
    public var timeouts: Int { countOutcome(.timeout) }

    private func countOutcome(_ o: Outcome) -> Int {
        results.reduce(0) { $0 + ($1.outcome == o ? 1 : 0) }
    }
    public var winRate: Double {
        runs == 0 ? 0 : Double(victories) / Double(runs)
    }

    public func livesPercentile(_ p: Double) -> Double {
        Percentile.of(results.map { Double($0.livesRemaining) }, p)
    }

    public var totalKilled: Int { results.reduce(0) { $0 + $1.killed } }
    public var totalRouted: Int { results.reduce(0) { $0 + $1.routed } }
    public var totalCaptured: Int { results.reduce(0) { $0 + $1.captured } }
    public var totalLeaked: Int { results.reduce(0) { $0 + $1.leaked } }

    public var routShare: Double {
        let removed = totalKilled + totalRouted + totalCaptured
        return removed == 0 ? 0 : Double(totalRouted + totalCaptured) / Double(removed)
    }

    public var meanWaveMaxProgress: [Double] {
        guard let first = results.first else { return [] }
        var sums = Array(repeating: 0.0, count: first.waveMaxProgress.count)
        for r in results {
            for (i, v) in r.waveMaxProgress.enumerated() where i < sums.count {
                sums[i] += v
            }
        }
        return sums.map { $0 / Double(results.count) }
    }
}

/// A run of `count` seeded simulations of one level, seeds `baseSeed`,
/// `baseSeed + 1`, ...
public struct Batch: Sendable {
    public let baseSeed: UInt64
    public let count: Int
    public let maxSeconds: Double

    public init(baseSeed: UInt64, count: Int, maxSeconds: Double = 900) {
        self.baseSeed = baseSeed
        self.count = count
        self.maxSeconds = maxSeconds
    }

    public func run(
        level: LevelInfo,
        catalog: ContentCatalog,
        makePolicy: (UInt64) -> any CommanderPolicy
    ) throws -> BatchReport {
        var results: [SimulationResult] = []
        results.reserveCapacity(count)
        for k in 0..<count {
            let seed = baseSeed &+ UInt64(k)
            let sim = try Simulation(
                level: level,
                catalog: catalog,
                policy: makePolicy(seed),
                seed: seed
            )
            results.append(sim.run(maxSeconds: maxSeconds))
        }
        return BatchReport(results: results)
    }
}
