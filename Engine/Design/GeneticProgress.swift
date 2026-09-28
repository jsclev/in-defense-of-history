import Foundation

/// Run-budget reporting only. This estimator never changes search or battle rules.
/// Search occupies 85%, validation 14%, and saving results the final 1%.
public struct GeneticProgress {
    public static let searchTimeFraction = 0.85

    public enum Phase: String, Codable {
        case search, validation, saving, completed, failed
    }

    public struct Milestone: Codable, Equatable {
        public let percent: Int
        /// When a completed work batch first showed that this threshold was passed.
        public let elapsedSeconds: Double
    }

    public struct Snapshot: Codable, Equatable {
        public let runID: UUID
        public let phase: Phase
        public let percentComplete: Double
        public let elapsedSeconds: Double
        public let estimatedSecondsRemaining: Double?
        public let completedGenerations: Int
        public let trainingEvaluations: Int
        public let validationEvaluations: Int
        public let milestones: [Milestone]

        public var statusLine: String {
            let percent = String(format: "%.1f", percentComplete)
            let remaining: String
            if phase == .completed { remaining = "finished" }
            else if phase == .failed { remaining = "failed" }
            else if phase == .saving { remaining = "saving results" }
            else if let seconds = estimatedSecondsRemaining {
                remaining = seconds > 0 ? "about \(GeneticProgress.duration(seconds.rounded(.up))) remaining" : "finishing current phase"
            } else { remaining = "estimating remaining time" }
            return "GA progress: \(phase == .completed ? "" : "~")\(percent)% | elapsed \(GeneticProgress.duration(elapsedSeconds)) | \(remaining) | \(phase.rawValue) | generations \(completedGenerations) | battles \(trainingEvaluations + validationEvaluations)"
        }
    }

    public static func duration(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let hours = total / 3600, minutes = (total % 3600) / 60, remainder = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m \(remainder)s" }
        if minutes > 0 { return "\(minutes)m \(remainder)s" }
        return "\(remainder)s"
    }

    private let runID: UUID
    private let startedAt: Double
    private let timeBudget: Double
    private let trainingLimit: Int
    private let generationLimit: Int
    private var validationStarted: Double?
    public private(set) var latest: Snapshot?

    public init(runID: UUID, startedAt: Double, timeBudget: Double,
                trainingLimit: Int, generationLimit: Int) {
        precondition(startedAt.isFinite && timeBudget.isFinite && timeBudget > 0)
        precondition(trainingLimit > 0 && generationLimit > 0)
        self.runID = runID
        self.startedAt = startedAt
        self.timeBudget = timeBudget
        self.trainingLimit = trainingLimit
        self.generationLimit = generationLimit
    }

    public mutating func update(now: Double, phase: Phase, completedGenerations: Int,
                                trainingEvaluations: Int, validationEvaluations: Int,
                                validationTarget: Int) -> Snapshot {
        precondition(now.isFinite)
        precondition(completedGenerations >= 0 && trainingEvaluations >= 0 && validationEvaluations >= 0 && validationTarget >= 0)
        if let latest, latest.phase == .completed || latest.phase == .failed { return latest }
        let elapsed = max(latest?.elapsedSeconds ?? 0, max(0, now - startedAt))
        let timeRemaining = max(0, timeBudget - elapsed)
        let searchBudget = timeBudget * Self.searchTimeFraction
        let overallRate = elapsed > 0 ? Double(trainingEvaluations + validationEvaluations) / elapsed : 0
        var fraction: Double
        var remaining: Double?
        switch phase {
        case .search:
            // Whichever stopping condition is reached first ends the search.
            fraction = Self.searchTimeFraction * min(1, max(elapsed / searchBudget,
                Double(trainingEvaluations) / Double(trainingLimit),
                Double(completedGenerations) / Double(generationLimit)))
            if trainingEvaluations > 0 && elapsed > 0 {
                let rate = Double(trainingEvaluations) / elapsed
                var searchRemaining = min(max(0, searchBudget - elapsed),
                    Double(max(0, trainingLimit - trainingEvaluations)) / rate)
                if completedGenerations > 0 {
                    searchRemaining = min(searchRemaining,
                        Double(max(0, generationLimit - completedGenerations)) * elapsed / Double(completedGenerations))
                }
                remaining = min(timeRemaining, searchRemaining + Double(validationTarget) / rate)
            }
        case .validation:
            if validationStarted == nil { validationStarted = elapsed }
            let duration = max(0, elapsed - validationStarted!)
            let budget = max(0.001, timeBudget - validationStarted!)
            let work = validationTarget > 0 ? Double(validationEvaluations) / Double(validationTarget) : 1
            fraction = Self.searchTimeFraction + 0.14 * min(1, max(work, duration / budget))
            let rate = duration > 0 && validationEvaluations > 0 ? Double(validationEvaluations) / duration : overallRate
            if validationEvaluations >= validationTarget { remaining = 0 }
            else if rate > 0 { remaining = min(timeRemaining, Double(validationTarget - validationEvaluations) / rate) }
        case .saving:
            fraction = 0.99
        case .completed:
            fraction = 1
            remaining = 0
        case .failed:
            fraction = (latest?.percentComplete ?? 0) / 100
        }
        // A slower later batch may increase ETA, but never moves the bar backward.
        // Budget expiry alone cannot claim completion before results are saved.
        let percent = phase == .completed ? 100 : min(99, max(latest?.percentComplete ?? 0, fraction * 100))
        var milestones = latest?.milestones ?? []
        if phase != .failed {
            while (milestones.last?.percent ?? 0) + 10 <= Int(percent) {
                milestones.append(Milestone(percent: (milestones.last?.percent ?? 0) + 10, elapsedSeconds: elapsed))
            }
        }
        let snapshot = Snapshot(runID: runID, phase: phase, percentComplete: percent,
            elapsedSeconds: elapsed, estimatedSecondsRemaining: remaining,
            completedGenerations: completedGenerations, trainingEvaluations: trainingEvaluations,
            validationEvaluations: validationEvaluations, milestones: milestones)
        latest = snapshot
        return snapshot
    }
}
