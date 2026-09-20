import Foundation

/// Invalid or missing level-map content, shared by the editor and game loader.
/// These errors describe GeoJSON files and never imply a SQLite operation.
public struct LevelGeoJSONError: LocalizedError, Equatable {
    public let message: String

    public init(message: String) { self.message = message }

    public var errorDescription: String? { message }
}
