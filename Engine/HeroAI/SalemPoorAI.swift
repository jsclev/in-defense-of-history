import Foundation

/// Dedicated decision policy for Salem Poor. Starts with the shared interception
/// tactic; hero-specific decisions can evolve here without changing other heroes.
final class SalemPoorAI: HeroAI {
    private let tactics = HeroAITactics()
    var isRecovering: Bool { tactics.isRecovering }
    func reset() { tactics.reset() }
    func destination(in context: HeroAIContext) -> Point? {
        tactics.interceptThreat(in: context)
    }
}
