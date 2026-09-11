import Foundation

/// Versioned, self-contained editor source. GeoJSON is a flattened derivative.
struct NativeMapFile: Codable {
    static let currentVersion = 1
    var format = "com.zippyzen.td.map"
    var version = Self.currentVersion
    var draft: MapDraft
    var canvas: VirtualCanvas

    static func read(_ data: Data) throws -> NativeMapFile {
        let file = try JSONDecoder().decode(Self.self, from: data)
        guard file.format == "com.zippyzen.td.map", file.version == currentVersion else {
            throw LevelGeoJSON.ValidationError(message: "This editor document uses an unsupported format version.")
        }
        return file
    }

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
