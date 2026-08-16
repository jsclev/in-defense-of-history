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

/// Files from the repo's common Images folder. On a Mac running from the
/// repo they are read straight from that folder (so a regenerated sprite
/// shows without rebuilding); on iPad — or any machine without the repo —
/// they come from the app bundle, where the Images folder is synchronized
/// into the LevelEditor target and lands flat.
enum EditorResources {
    static func url(_ relativePath: String) -> URL? {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: repo.path) { return repo }
        let name = (relativePath as NSString).lastPathComponent
        return Bundle.main.url(
            forResource: (name as NSString).deletingPathExtension,
            withExtension: (name as NSString).pathExtension)
    }
}

extension EditorResources {
    /// A repo image as a template-rendered toolbar icon at the given point
    /// size, so it tints like an SF Symbol on both platforms.
    static func templateIcon(_ relativePath: String, pointSize: CGFloat) -> Image? {
        guard let url = url(relativePath),
              let loaded = PlatformImageLoader.load(path: url.path) else { return nil }
        #if canImport(AppKit)
        let image = loaded.image
        image.size = NSSize(width: pointSize, height: pointSize)
        image.isTemplate = true
        return Image(nsImage: image)
        #else
        guard let cg = loaded.image.cgImage else { return nil }
        let scaled = UIImage(cgImage: cg, scale: loaded.pixelSize.width / pointSize,
                             orientation: .up)
        return Image(uiImage: scaled).renderingMode(.template)
        #endif
    }
}

enum PlatformImageLoader {
    static func load(path: String) -> (image: PlatformImage, pixelSize: CGSize)? {
        load(url: URL(fileURLWithPath: path))
    }

    /// Reads the file's CURRENT bytes and decodes them. NSImage/UIImage
    /// (contentsOfFile:) does not download an iCloud Drive placeholder and
    /// can serve a stale copy of a file Finder already shows as up to date.
    /// This nudges the download for a not-yet-current iCloud item and reads
    /// the bytes uncached, so a re-picked, updated-in-place file decodes
    /// fresh. Deliberately no NSFileCoordinator and no blocking wait: both
    /// can stall the main thread against the file-provider daemon, which in
    /// the editor showed as a picked layer never appearing.
    static func load(url: URL) -> (image: PlatformImage, pixelSize: CGSize)? {
        guard let data = freshRead(url) else { return nil }
        #if canImport(AppKit)
        guard let image = NSImage(data: data),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        return (image, CGSize(width: cg.width, height: cg.height))
        #else
        guard let image = UIImage(data: data), let cg = image.cgImage
        else { return nil }
        return (image, CGSize(width: cg.width, height: cg.height))
        #endif
    }

    private static func freshRead(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        if fm.isUbiquitousItem(at: url) {
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
            if status != .current {
                try? fm.startDownloadingUbiquitousItem(at: url)
            }
        }
        return try? Data(contentsOf: url, options: [.uncached])
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

enum NudgeDirection {
    case up, down, left, right
}

extension View {
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

struct EditorSplit<Sidebar: View, Detail: View>: View {
    var showSidebar = true
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail

    var body: some View {
        #if os(macOS)
        HSplitView {
            if showSidebar {
                // Wide enough that no layer row in the panel ever wraps.
                sidebar.frame(minWidth: 340, idealWidth: 380, maxWidth: 460)
                    .transition(.move(edge: .leading))
            }
            detail.frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        HStack(spacing: 0) {
            if showSidebar {
                sidebar.frame(width: 380)
                    .transition(.move(edge: .leading))
                Divider()
            }
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #endif
    }
}
