import AppKit
import SwiftUI
import LevelEditorFormats
import SwiftUI

@available(iOS 26.0, *)
struct HudMasterControlsView: View {
    private let layout: MasterControlsLayout
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    public init(runtimeCanvas: RuntimeCanvas,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        self.layout = MasterControlsLayout(runtimeCanvas: runtimeCanvas)
    }

    var body: some View {
        HStack(spacing: layout.buttonSpacing) {
            HudButtonView(iconName: "speed_up_icon_glyph", buttonSize: layout.buttonSize,
                          iconScale: HudSizing.masterControlIconFraction,
                          action: onSpeedUp)
            HudButtonView(iconName: "pause_icon_glyph", buttonSize: layout.buttonSize,
                          iconScale: HudSizing.masterControlIconFraction,
                          action: onExit)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}

import SwiftUI

struct HudButtonView: View {
    private let iconName: String
    private let buttonSize: CGFloat
    private let iconScale: CGFloat
    private let action: () -> Void
    
    public init(iconName: String, buttonSize: CGFloat, iconScale: CGFloat = 0.80,
                action: @escaping () -> Void) {
        self.iconName = iconName
        self.buttonSize = buttonSize
        self.iconScale = iconScale
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(nsImage: Proof.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
                Image(nsImage: Proof.art(iconName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * iconScale, height: buttonSize * iconScale)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
import SwiftUI

@available(iOS 26.0, *)
struct BeforeHudMasterControlsView: View {
    private let buttonSize: CGFloat
    private let buttonSpacing: CGFloat
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    public init(runtimeCanvas: RuntimeCanvas,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        let width = runtimeCanvas.masterControlsSize.width
        let height = runtimeCanvas.masterControlsSize.height
        let minDimension = max(width, height)

        self.buttonSize = (minDimension / 2.0) * 0.90
        self.buttonSpacing = (minDimension / 2.0) * 0.10
    }

    var body: some View {
        HStack(spacing: buttonSpacing) {
            HudButtonView(iconName: "speed_up_icon_glyph", buttonSize: buttonSize,
                          iconScale: HudSizing.masterControlIconFraction,
                          action: onSpeedUp)
            HudButtonView(iconName: "pause_icon_glyph", buttonSize: buttonSize,
                          iconScale: HudSizing.masterControlIconFraction,
                          action: onExit)
        }
    }
}

@main struct Proof {
    @MainActor static var density = 1
    @MainActor static func art(_ name: String) -> NSImage {
        let base = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
        let info = try! JSONSerialization.jsonObject(with: Data(contentsOf: base.appendingPathComponent("Contents.json"))) as! [String: Any]
        let entries = (info["images"] as! [[String: Any]]).filter { $0["filename"] != nil }
        let entry = entries.first { $0["scale"] as? String == "\(density)x" } ?? entries[0]
        return NSImage(contentsOf: base.appendingPathComponent(entry["filename"] as! String))!
    }
    static func values(_ r: CGRect) -> [CGFloat] { [r.minX, r.minY, r.width, r.height] }
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let db = Db(dbPath: out.appendingPathComponent("fixture.sqlite").path, fullRefresh: false)
        let vc = try db.virtualCanvasDao.get()
        let minimum = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let fixtures: [(String, CGRect, CGRect)] = [
            ("minimum", minimum, minimum),
            ("phone", CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382)),
            ("tablet", CGRect(x: 0, y: 0, width: 1024, height: 768), CGRect(x: 0, y: 24, width: 1024, height: 724))
        ]
        var measurements: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let layout = MasterControlsLayout(runtimeCanvas: runtime)
            let occlusion = CGRect(x: runtime.playAreaRect.maxX - vc.upperRightOcclusionArea.width * runtime.scaleFactor,
                                   y: runtime.playAreaRect.minY,
                                   width: vc.upperRightOcclusionArea.width * runtime.scaleFactor,
                                   height: vc.upperRightOcclusionArea.height * runtime.scaleFactor)
            let oldHalf = max(runtime.masterControlsSize.width, runtime.masterControlsSize.height) / 2
            if name == "phone" {
                precondition(layout.buttonSize > oldHalf * 0.9)
                precondition(abs(layout.frame.maxY - occlusion.maxY) < 1e-8)
            }
            measurements.append(["fixture": name, "beforeButton": oldHalf * 0.9,
                                 "button": layout.buttonSize, "gap": layout.buttonSpacing,
                                 "frame": values(layout.frame), "hud": values(runtime.hudRect),
                                 "occlusion": values(occlusion)])
            for d in [1, 2, 3] {
                density = d
                let row = HudMasterControlsView(runtimeCanvas: runtime, onSpeedUp: {}, onExit: {})
                let before = BeforeHudMasterControlsView(runtimeCanvas: runtime, onSpeedUp: {}, onExit: {})
                try save(row.padding(7), name: "\(name)-after", out: out)
                try save(before.padding(7), name: "\(name)-before", out: out)
                if name == "minimum" {
                    for icon in ["speed_up_icon_glyph", "pause_icon_glyph"] {
                        try save(HudButtonView(iconName: icon, buttonSize: layout.buttonSize,
                            iconScale: HudSizing.masterControlIconFraction, action: {}).padding(7), name: icon, out: out)
                    }
                }
                if d == 1 {
                    try save(scene(runtime: runtime, physical: physical, occlusion: occlusion, row: row), name: "\(name)-guides", out: out)
                    try save(scene(runtime: runtime, physical: physical, occlusion: occlusion, row: before), name: "\(name)-before-guides", out: out)
                }
            }
        }
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("layout.json"))
    }
    @MainActor static func scene<V: View>(runtime: RuntimeCanvas, physical: CGRect, occlusion: CGRect, row: V) -> some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.15, green: 0.18, blue: 0.12)
            Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/ArtReadability/reports/hero-hud-2026-09-08/battle-road-under.jpg")!)
                .resizable().frame(width: runtime.playAreaRect.width, height: runtime.playAreaRect.height)
                .position(x: runtime.playAreaRect.midX, y: runtime.playAreaRect.midY)
            Rectangle().fill(Color.blue.opacity(0.2))
                .frame(width: runtime.hudRect.maxX - max(occlusion.minX, runtime.hudRect.minX), height: min(occlusion.maxY, runtime.hudRect.maxY) - runtime.hudRect.minY)
                .position(x: (runtime.hudRect.maxX + max(occlusion.minX, runtime.hudRect.minX)) / 2,
                          y: (min(occlusion.maxY, runtime.hudRect.maxY) + runtime.hudRect.minY) / 2)
            // Match HudView's top-trailing overlay inside its full HUD rectangle.
            Color.clear.frame(width: runtime.hudRect.width, height: runtime.hudRect.height)
                .overlay(alignment: .topTrailing) { row }
                .position(x: runtime.hudRect.midX, y: runtime.hudRect.midY)
            SwiftUI.Path(runtime.runtimePlayArea).stroke(.pink, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            Rectangle().stroke(.yellow, style: StrokeStyle(lineWidth: 1, dash: [9, 6]))
                .frame(width: runtime.hudRect.width, height: runtime.hudRect.height)
                .position(x: runtime.hudRect.midX, y: runtime.hudRect.midY)
        }.frame(width: physical.width, height: physical.height).clipped()
    }
    @MainActor static func save<V: View>(_ view: V, name: String, out: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(density)
        guard let cg = renderer.cgImage else { fatalError("No render") }
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name)@\(density)x.png"))
    }
}
