#if os(macOS)
import AppKit

/// Coordinates the macOS document windows without replacing DocumentGroup's
/// normal Open, Open Recent, Save, or recovery handling.
@MainActor
final class EditorDocumentLifecycle {
    static let shared = EditorDocumentLifecycle(controller: .shared)

    private let controller: NSDocumentController
    private var openingRecentDocument = false

    init(controller: NSDocumentController) {
        self.controller = controller
    }

    /// Recent-menu order reflects opening, not editing. Use modification dates
    /// so inspecting an older map does not make it the next startup document.
    static func recentMapsByModificationDate(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.enumerated().compactMap { index, url -> (URL, Date, Int)? in
            guard url.isFileURL, url.pathExtension.lowercased() == "tdmap",
                  seen.insert(url.standardizedFileURL).inserted else { return nil }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, index)
        }.sorted {
            $0.1 == $1.1 ? $0.2 < $1.2 : $0.1 > $1.1
        }.map { $0.0 }
    }

    func openInitialDocument() {
        guard !openingRecentDocument else { return }
        guard controller.documents.isEmpty else {
            controller.documents.forEach { $0.showWindows() }
            return
        }
        openingRecentDocument = true
        openNextRecentDocument(Self.recentMapsByModificationDate(controller.recentDocumentURLs))
    }

    private func openNextRecentDocument(_ urls: [URL]) {
        // An explicit Open or Finder request may have arrived during startup.
        guard controller.documents.isEmpty else {
            openingRecentDocument = false
            return
        }
        guard let url = urls.first else {
            openingRecentDocument = false
            controller.newDocument(nil)
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        controller.openDocument(withContentsOf: url, display: true) { [self] document, _, _ in
            if scoped { url.stopAccessingSecurityScopedResource() }
            if document != nil {
                openingRecentDocument = false
                documentDidOpen(at: url)
            } else {
                // A removed, unreadable, or corrupt recent file should not
                // prevent the editor from starting with another map.
                openNextRecentDocument(Array(urls.dropFirst()))
            }
        }
    }

    func documentDidOpen(at url: URL) {
        // Only remove placeholders after the requested file opened successfully.
        guard controller.document(for: url) != nil else { return }
        for document in controller.documents where document.fileURL == nil
            && document.autosavedContentsFileURL == nil && !document.isDocumentEdited {
            document.close()
        }
    }
}
#endif
