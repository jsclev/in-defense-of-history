import Foundation

/// Authored copy for one specific tower level and branch, loaded from SQLite.
public struct TowerMenuDetails: Equatable, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}
