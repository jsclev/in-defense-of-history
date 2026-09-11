#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import LevelEditorFormats

@MainActor
final class EditorArrowKeyTests: XCTestCase {
    private final class Window: NSWindow {
        var active = true
        override var isKeyWindow: Bool { active }
    }

    private final class FocusableView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    private func makeWindow() -> Window {
        _ = NSApplication.shared
        // Never ordered on screen and never takes focus from the user's app.
        return Window(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                      styleMask: [.titled], backing: .buffered, defer: false)
    }

    private func key(_ code: UInt16, in window: NSWindow,
                     modifiers: NSEvent.ModifierFlags = [.function, .numericPad],
                     repeatKey: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                         timestamp: 0, windowNumber: window.windowNumber, context: nil,
                         characters: "", charactersIgnoringModifiers: "",
                         isARepeat: repeatKey, keyCode: code)!
    }

    private func install(in window: NSWindow) -> EditorArrowKeyView {
        let view = EditorArrowKeyView()
        view.canMove = { true }
        window.contentView!.addSubview(view)
        return view
    }

    func testAllArrowsReachSelectionWithFocusOutsideCanvasExactlyOnce() {
        let window = makeWindow()
        let input = install(in: window)
        defer { input.removeFromSuperview() }
        let inspector = FocusableView()
        window.contentView!.addSubview(inspector)
        XCTAssertTrue(window.makeFirstResponder(inspector))
        var directions: [NudgeDirection] = []
        input.onMove = { directions.append($0) }

        let sample = key(124, in: window)
        XCTAssertTrue(sample.window === window, "event window: \(String(describing: sample.window)); number \(window.windowNumber)")
        XCTAssertFalse(input.isHiddenOrHasHiddenAncestor)
        XCTAssertNil(window.attachedSheet)
        XCTAssertNil(NSApp.modalWindow)
        XCTAssertFalse(window.firstResponder is NSTextInputClient)

        for code: UInt16 in [123, 124, 125, 126] {
            XCTAssertTrue(input.handleArrowKey(key(code, in: window)))
        }
        XCTAssertEqual(directions, [.left, .right, .down, .up])
    }

    func testSwiftUIHostingViewDoesNotBlockCanvasArrows() {
        let window = makeWindow()
        let input = install(in: window)
        defer { input.removeFromSuperview() }
        let host = NSHostingView(rootView: Text("Map canvas").focusable())
        window.contentView!.addSubview(host)
        XCTAssertTrue(window.makeFirstResponder(host))
        XCTAssertTrue(input.handleArrowKey(key(124, in: window)))
    }

    func testTextFieldEditorKeepsArrowKeys() {
        let window = makeWindow()
        let input = install(in: window)
        defer { input.removeFromSuperview() }
        let text = NSTextView()
        text.isFieldEditor = true
        window.contentView!.addSubview(text)
        XCTAssertTrue(window.makeFirstResponder(text))
        var moves = 0
        input.onMove = { _ in moves += 1 }
        for code: UInt16 in [123, 124, 125, 126] {
            XCTAssertFalse(input.handleArrowKey(key(code, in: window)))
        }
        XCTAssertEqual(moves, 0)

        let canvas = FocusableView()
        window.contentView!.addSubview(canvas)
        XCTAssertTrue(window.makeFirstResponder(canvas))
        XCTAssertTrue(input.handleArrowKey(key(124, in: window)))
        XCTAssertEqual(moves, 1)
    }

    func testInactiveAndOtherDocumentWindowsCannotNudge() {
        let window = makeWindow(), other = makeWindow()
        let input = install(in: window)
        defer { input.removeFromSuperview() }
        XCTAssertFalse(input.handleArrowKey(key(124, in: other)))
        window.active = false
        XCTAssertFalse(input.handleArrowKey(key(124, in: window)))
        window.active = true
        XCTAssertTrue(input.handleArrowKey(key(124, in: window)))
    }

    func testShortcutsAndNonArrowKeysPassThrough() {
        let window = makeWindow()
        let input = install(in: window)
        defer { input.removeFromSuperview() }
        for modifier: NSEvent.ModifierFlags in [.command, .control, .option, .shift] {
            XCTAssertFalse(input.handleArrowKey(key(124, in: window, modifiers: modifier)))
        }
        XCTAssertFalse(input.handleArrowKey(key(0, in: window)))
        XCTAssertTrue(input.handleArrowKey(key(124, in: window, modifiers: [.capsLock, .function])))
    }

    func testSelectionChangesAndKeyRepeatUseCurrentHandler() {
        let window = makeWindow()
        let input = install(in: window)
        defer { input.removeFromSuperview() }
        var selected = false
        var moves = 0
        input.canMove = { selected }
        input.onMove = { _ in moves += 1 }
        XCTAssertFalse(input.handleArrowKey(key(124, in: window)))
        selected = true
        XCTAssertTrue(input.handleArrowKey(key(124, in: window)))
        XCTAssertTrue(input.handleArrowKey(key(124, in: window, repeatKey: true)))
        XCTAssertEqual(moves, 2)
        selected = false
        XCTAssertFalse(input.handleArrowKey(key(124, in: window)))
        XCTAssertEqual(moves, 2)
    }

    func testHiddenOrDetachedCanvasCannotConsumeArrows() {
        let window = makeWindow()
        let input = install(in: window)
        input.isHidden = true
        XCTAssertFalse(input.handleArrowKey(key(124, in: window)))
        input.isHidden = false
        XCTAssertTrue(input.handleArrowKey(key(124, in: window)))
        input.removeFromSuperview()
        XCTAssertFalse(input.handleArrowKey(key(124, in: window)))
    }
}
#endif
