// LevelEditorApp.swift
import SwiftUI
import AppKit

// DocumentGroup's macOS default is an Open panel at launch; we suppress that
// scene and open an untitled map ourselves so the editor GUI just appears.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private func openUntitledIfNoWindows() {
        let hasWindow = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
        if !hasWindow {
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Give window restoration a beat; only create a fresh map if it
        // brought nothing back.
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

@main
struct LevelEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: { MapDocument() }) { config in
            EditorView(document: config.document)
        }
        .defaultSize(width: 1380, height: 900)
        .defaultLaunchBehavior(.suppressed)
        .commands { ZoomCommands() }
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

// Photoshop's View-menu zoom set: ⌘+ / ⌘- step the preset ladder,
// ⌘0 fits on screen, ⌘1 shows actual pixels.
struct ZoomCommands: Commands {
    @FocusedValue(\.editorState) private var state

    var body: some Commands {
        CommandGroup(after: .toolbar) {
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
