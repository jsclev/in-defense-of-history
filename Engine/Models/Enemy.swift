import Foundation

public enum EnemyFate: String, Codable, Sendable {
    case killed
    case routed
    case captured
    case leaked
}
