#if os(macOS)
import AppKit
import XCTest
@testable import LevelEditorFormats

@MainActor
final class EditorDocumentLifecycleTests: XCTestCase {
    private class Document: NSDocument {
        var edited = false
        var closeCount = 0
        var showCount = 0
        override var isDocumentEdited: Bool { edited }
        override func close() { closeCount += 1 }
        override func showWindows() { showCount += 1 }
    }

    private class Controller: NSDocumentController {
        var recents: [URL] = []
        var opened: [NSDocument] = []
        var failing = Set<URL>()
        var requests: [URL] = []
        var newCount = 0
        override var recentDocumentURLs: [URL] { recents }
        override var documents: [NSDocument] { opened }
        override func newDocument(_ sender: Any?) {
            newCount += 1
            opened.append(Document())
        }
        override func openDocument(withContentsOf url: URL, display: Bool,
                                   completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
            requests.append(url)
            if failing.contains(url) {
                completionHandler(nil, false, CocoaError(.fileReadCorruptFile))
            } else {
                let document = Document()
                document.fileURL = url
                opened.append(document)
                completionHandler(document, false, nil)
            }
        }
    }

    private func makeController() -> Controller {
        // NSDocumentController returns its existing singleton from init.
        // Clear this test double between cases without touching the real app.
        let controller = Controller()
        controller.recents = []
        controller.opened = []
        controller.failing = []
        controller.requests = []
        controller.newCount = 0
        return controller
    }

    private func withRecentFiles(_ action: ([URL]) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = ["old.tdmap", "new.TDMAP", "export.geojson"].enumerated().map { index, name in
            (folder.appendingPathComponent(name), Date(timeIntervalSince1970: Double(index + 1) * 1000))
        }
        for (url, date) in urls {
            try Data("{}".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        try action(urls.map(\.0))
    }

    func testStartupUsesLastEditInsteadOfLastOpenAndCreatesNoUntitledWindow() throws {
        try withRecentFiles { urls in
            let controller = makeController()
            controller.recents = urls + [urls[1], urls[0].deletingLastPathComponent().appendingPathComponent("missing.tdmap")]
            XCTAssertEqual(EditorDocumentLifecycle.recentMapsByModificationDate(controller.recents), [urls[1], urls[0]])
            EditorDocumentLifecycle(controller: controller).openInitialDocument()
            XCTAssertEqual(controller.requests, [urls[1]])
            XCTAssertEqual(controller.newCount, 0)
            XCTAssertEqual(controller.documents.count, 1)
        }
    }

    func testUnreadableRecentFallsBackToNextMapThenUntitled() throws {
        try withRecentFiles { urls in
            let controller = makeController()
            controller.recents = urls
            controller.failing = [urls[1]]
            EditorDocumentLifecycle(controller: controller).openInitialDocument()
            XCTAssertEqual(controller.requests, [urls[1], urls[0]])
            XCTAssertEqual(controller.newCount, 0)

            controller.opened = []
            controller.failing.insert(urls[0])
            EditorDocumentLifecycle(controller: controller).openInitialDocument()
            XCTAssertEqual(controller.newCount, 1)
        }
    }

    func testNoRecentFilesCreatesOnlyOneUntitledDocument() {
        let controller = makeController()
        let lifecycle = EditorDocumentLifecycle(controller: controller)
        lifecycle.openInitialDocument()
        lifecycle.openInitialDocument()
        XCTAssertEqual(controller.newCount, 1)
        XCTAssertEqual(controller.documents.count, 1)
    }

    func testExplicitlyOpenedDocumentTakesPriorityOverStartupRecents() throws {
        try withRecentFiles { urls in
            let controller = makeController()
            controller.recents = urls
            let document = Document()
            document.fileURL = urls[0]
            controller.opened = [document]
            EditorDocumentLifecycle(controller: controller).openInitialDocument()
            XCTAssertTrue(controller.requests.isEmpty)
            XCTAssertEqual(controller.newCount, 0)
            XCTAssertEqual(document.showCount, 1)
        }
    }

    func testSuccessfulOpenClosesOnlyPristineUntitledDocuments() {
        let controller = makeController()
        let pristine = Document(), edited = Document(), recovered = Document(), saved = Document()
        edited.edited = true
        recovered.autosavedContentsFileURL = URL(fileURLWithPath: "/tmp/recovered.tdmap")
        saved.fileURL = URL(fileURLWithPath: "/tmp/opened.tdmap")
        controller.opened = [pristine, edited, recovered, saved]
        EditorDocumentLifecycle(controller: controller).documentDidOpen(at: saved.fileURL!)
        XCTAssertEqual(pristine.closeCount, 1)
        XCTAssertEqual(edited.closeCount, 0)
        XCTAssertEqual(recovered.closeCount, 0)
        XCTAssertEqual(saved.closeCount, 0)
    }

    func testFailedOpenKeepsUntitledDocument() {
        let controller = makeController()
        let pristine = Document()
        controller.opened = [pristine]
        EditorDocumentLifecycle(controller: controller).documentDidOpen(at: URL(fileURLWithPath: "/tmp/missing.tdmap"))
        XCTAssertEqual(pristine.closeCount, 0)
    }
}
#endif
