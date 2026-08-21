import SwiftUI

#if os(macOS)
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private func openUntitledIfNoWindows() {
        let hasWindow = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
        if !hasWindow {
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.openUntitledIfNoWindows()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
            return false
        }
        return true
    }
}
#endif

@main
struct LevelEditorApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        // The editor cannot draw a canvas without the coordinate system in
        // virtual_canvas. EditorContent opens the database and loads it; if the
        // file is missing there is nothing sane to fall back to.
        _ = EditorContent.shared
        guard VirtualCanvas.isLoaded else {
            fatalError("LevelEditor could not load the virtual_canvas table. "
                + "On the Mac, run Db/create_db.sh to refresh "
                + "~/Documents/in_defense_of_history.sqlite; on iPad, "
                + "reinstall so the bundled database is current.")
        }
    }

    var body: some Scene {
        #if os(macOS)
        DocumentGroup(newDocument: { MapDocument() }) { config in
            EditorView(document: config.document, documentURL: config.fileURL)
        }
        .defaultSize(width: 1380, height: 900)
        .defaultLaunchBehavior(.suppressed)
        .commands { ZoomCommands() }
        #else
        DocumentGroup(newDocument: { MapDocument() }) { config in
            EditorView(document: config.document, documentURL: config.fileURL)
        }
        .commands { ZoomCommands() }
        #endif
    }
}

struct EditorStateKey: FocusedValueKey {
    typealias Value = EditorState
}

extension FocusedValues {
    var editorState: EditorState? {
        get { self[EditorStateKey.self] }
        set { self[EditorStateKey.self] = newValue }
    }
}

struct ZoomCommands: Commands {
    @FocusedValue(\.editorState) private var state

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(state?.showInspector == false ? "Show Inspector" : "Hide Inspector") {
                state?.toggleInspector()
            }
            .keyboardShortcut("s", modifiers: [.control, .command])
            .disabled(state == nil)
            Divider()
            Button("Zoom In") { state?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(state == nil)
            Button("Zoom Out") { state?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(state == nil)
            Divider()
            Button("Fit on Screen") { state?.zoomFit() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(state == nil)
            Button("100%") { state?.setZoom(1) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(state == nil)
            Button("200%") { state?.setZoom(2) }
                .disabled(state == nil)
            Divider()
        }
    }
}
