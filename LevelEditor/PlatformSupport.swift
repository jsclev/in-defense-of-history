import SwiftUI

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

enum PlatformImageLoader {
    static func load(path: String) -> (image: PlatformImage, pixelSize: CGSize)? {
        #if canImport(AppKit)
        guard let image = NSImage(contentsOfFile: path),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        return (image, CGSize(width: cg.width, height: cg.height))
        #else
        guard let image = UIImage(contentsOfFile: path), let cg = image.cgImage
        else { return nil }
        return (image, CGSize(width: cg.width, height: cg.height))
        #endif
    }
}

enum PlatformPasteboard {
    static func copy(_ string: String) {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}

/// `MoveCommandDirection` is macOS-only, so arrow-key nudging speaks this instead.
enum NudgeDirection {
    case up, down, left, right
}

extension View {
    /// `onDeleteCommand` / `onExitCommand` / `onMoveCommand` are macOS-only.
    /// iPadOS gets the same actions through hardware-keyboard shortcuts.
    @ViewBuilder
    func platformEditingCommands(
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onMove: @escaping (NudgeDirection) -> Void
    ) -> some View {
        #if os(macOS)
        self.onDeleteCommand(perform: onDelete)
            .onExitCommand(perform: onCancel)
            .onMoveCommand { direction in
                switch direction {
                case .up: onMove(.up)
                case .down: onMove(.down)
                case .left: onMove(.left)
                case .right: onMove(.right)
                @unknown default: break
                }
            }
        #else
        self.onKeyPress(.delete) { onDelete(); return .handled }
            .onKeyPress(.deleteForward) { onDelete(); return .handled }
            .onKeyPress(.escape) { onCancel(); return .handled }
            .onKeyPress(.upArrow) { onMove(.up); return .handled }
            .onKeyPress(.downArrow) { onMove(.down); return .handled }
            .onKeyPress(.leftArrow) { onMove(.left); return .handled }
            .onKeyPress(.rightArrow) { onMove(.right); return .handled }
        #endif
    }
}

/// Side-by-side inspector and canvas. `HSplitView` is macOS-only, so iOS gets a
/// plain fixed-width column instead.
struct EditorSplit<Sidebar: View, Detail: View>: View {
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail

    var body: some View {
        #if os(macOS)
        HSplitView {
            sidebar.frame(minWidth: 290, idealWidth: 330, maxWidth: 420)
            detail.frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        HStack(spacing: 0) {
            sidebar.frame(width: 330)
            Divider()
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #endif
    }
}
