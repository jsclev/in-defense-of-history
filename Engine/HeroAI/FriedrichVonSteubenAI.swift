import Foundation

/// Dedicated decision policy for Friedrich von Steuben. Starts with the shared interception
/// tactic; hero-specific decisions can evolve here without changing other heroes.
final class FriedrichVonSteubenAI: HeroAI {
    private let tactics = HeroAITactics()
    var isRecovering: Bool { tactics.isRecovering }
    func reset() { tactics.reset() }
    func destination(in context: HeroAIContext) -> Point? {
        tactics.interceptThreat(in: context)
    }
}
