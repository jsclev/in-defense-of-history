import UniformTypeIdentifiers
import XCTest
@testable import LevelEditorFormats

final class EditorFileImporterTests: XCTestCase {
    func testDismissalRetainsImageLayerAndReopeningAfterGeoJSONUsesImageTypes() {
        var presentation = EditorFileImportPresentation()
        for layer: EditorImageImportTarget in [.background, .overlay, .guide] {
            presentation.present(.geoJSON)
            XCTAssertEqual(presentation.target.contentTypes, GeoJSONFile.readableContentTypes + [.json])
            presentation.isPresented = false

            presentation.present(.image(layer))
            XCTAssertTrue(presentation.isPresented)
            XCTAssertEqual(presentation.target.contentTypes, [.png, .jpeg, .tiff])
            presentation.isPresented = false
            XCTAssertEqual(presentation.target, .image(layer))
            presentation.present(.image(layer))
            XCTAssertTrue(presentation.isPresented, "Choosing the same layer after cancel must reopen")
        }
    }

    func testAllChooseActionsUseTheSamePresentationState() {
        var presentation = EditorFileImportPresentation()
        XCTAssertFalse(presentation.isPresented)
        for target: EditorFileImportPresentation.Target in [
            .image(.background), .image(.overlay), .image(.guide), .geoJSON
        ] {
            presentation.present(target)
            XCTAssertTrue(presentation.isPresented)
            XCTAssertEqual(presentation.target, target)
            presentation.isPresented = false
        }
    }
}
