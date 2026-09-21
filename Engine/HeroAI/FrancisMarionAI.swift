import Foundation

/// Dedicated decision policy for Francis Marion. Starts with the shared interception
/// tactic; hero-specific decisions can evolve here without changing other heroes.
final class FrancisMarionAI: HeroAI {
    private let tactics = HeroAITactics()
    var isRecovering: Bool { tactics.isRecovering }
    func reset() { tactics.reset() }
    func destination(in context: HeroAIContext) -> Point? {
        tactics.interceptThreat(in: context)
    }
}
