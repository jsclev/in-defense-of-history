import SwiftUI
import UniformTypeIdentifiers

/// Thin wrapper so `.fileExporter` can write the encoded geojson. Read support
/// exists only because `FileDocument` requires it; the editor never imports.
struct GeoJSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.geoJSON, .json] }
    static var writableContentTypes: [UTType] { [.geoJSON, .json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
