import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI save-panel adapter; all bytes come from the validated model.
struct GeoJSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.geoJSON] }
    static var writableContentTypes: [UTType] { [.geoJSON] }

    let document: LevelGeoJSON

    init(document: LevelGeoJSON) { self.document = document }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        document = try LevelGeoJSON(data: contents)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try document.data())
    }
}
