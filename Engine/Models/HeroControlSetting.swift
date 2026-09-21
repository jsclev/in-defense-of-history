import Foundation

public struct HeroControlSetting: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let unlocked: Bool
    public let aiEnabled: Bool
}
