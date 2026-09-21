import Foundation

/// Dedicated decision policy for Nathanael Greene. Starts with the shared interception
/// tactic; hero-specific decisions can evolve here without changing other heroes.
final class NathanaelGreeneAI: HeroAI {
    private let tactics = HeroAITactics()
    var isRecovering: Bool { tactics.isRecovering }
    func reset() { tactics.reset() }
    func destination(in context: HeroAIContext) -> Point? {
        tactics.interceptThreat(in: context)
    }
}
