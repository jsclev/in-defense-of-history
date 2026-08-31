import SwiftUI

enum EditorLayer: String, CaseIterable, Identifiable {
    case background
    case mapGuide
    case path
    case slots
    case exits
    case entrances
    case occlusion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .background: "Background"
        case .mapGuide: "Guide"
        case .path: "Path"
        case .slots: "Tower Slots"
        case .exits: "Exits"
        case .entrances: "Entrances"
        case .occlusion: "Occlusion"
        }
    }

    var icon: String {
        switch self {
        case .background: "photo"
        case .mapGuide: "map"
        case .path: "point.topleft.down.to.point.bottomright.curvepath"
        case .slots: "circle.grid.cross"
        case .exits: "flag.checkered"
        case .entrances: "arrow.right.circle"
        case .occlusion: "square.2.layers.3d.top.filled"
        }
    }

    static var panelOrder: [EditorLayer] { allCases.reversed() }
}

extension EditorTool {
    var layer: EditorLayer? {
        switch self {
        case .brush, .paint, .eraser: .path
        case .slot: .slots
        case .entrance: .entrances
        case .exitPoint: .exits
        case .select, .zoomIn, .zoomOut: nil
        }
    }

    var title: String {
        switch self {
        case .select: "Select"
        case .brush: "Path tool"
        case .paint: "Path painter"
        case .eraser: "Path eraser"
        case .slot: "Slot placer"
        case .entrance: "Entrance placer"
        case .exitPoint: "Exit placer"
        case .zoomIn: "Zoom in"
        case .zoomOut: "Zoom out"
        }
    }
}

#if os(macOS)
extension EditorTool {
    private static let cursors: [EditorTool: NSCursor] = {
        var cursors: [EditorTool: NSCursor] = [
            .select: .arrow, .zoomIn: .zoomIn, .zoomOut: .zoomOut,
        ]
        func symbolImage(_ name: String) -> NSImage? {
            NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold))
        }
        func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
            let result = NSImage(size: image.size)
            result.lockFocus()
            image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            color.set()
            NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
            result.unlockFocus()
            return result
        }
        func haloed(_ image: NSImage) -> NSCursor {
            let side = max(image.size.width, image.size.height) + 4
            let canvas = NSImage(size: NSSize(width: side, height: side))
            let origin = NSPoint(x: (side - image.size.width) / 2,
                                 y: (side - image.size.height) / 2)
            canvas.lockFocus()
            let white = tinted(image, .white)
            for dx in [-1.0, 0, 1] {
                for dy in [-1.0, 0, 1] where dx != 0 || dy != 0 {
                    white.draw(at: NSPoint(x: origin.x + dx, y: origin.y + dy),
                               from: .zero, operation: .sourceOver, fraction: 1)
                }
            }
            tinted(image, .black).draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            canvas.unlockFocus()
            return NSCursor(image: canvas, hotSpot: NSPoint(x: side / 2, y: side / 2))
        }
        let symbols: [EditorTool: String] = [
            .brush: "scribble", .paint: "paintbrush.pointed", .eraser: "eraser",
            .entrance: "arrow.right.circle", .exitPoint: "flag.checkered",
        ]
        for (tool, name) in symbols {
            if let image = symbolImage(name) { cursors[tool] = haloed(image) }
        }
        if let url = EditorResources.url("Images/tower_tool_icon.png"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true
            cursors[.slot] = haloed(icon)
        } else if let image = symbolImage("building.fill") {
            cursors[.slot] = haloed(image)
        }
        return cursors
    }()

    var nsCursor: NSCursor { Self.cursors[self] ?? .arrow }
}
#endif
