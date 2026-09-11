import AppKit
import SwiftUI
import LevelEditorFormats

@main struct OcclusionProof {
    static func values(_ rect: CGRect) -> [CGFloat] {
        [rect.minX, rect.minY, rect.width, rect.height]
    }

    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let db = Db(dbPath: out.appendingPathComponent("fixture.sqlite").path, fullRefresh: false)
        let vc = try db.virtualCanvasDao.get()
        let minimum = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let fixtures: [(String, CGRect, CGRect)] = [
            ("minimum", minimum, minimum),
            ("phone", CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382)),
            ("ipad-mini", CGRect(x: 0, y: 0, width: 1133, height: 744), CGRect(x: 0, y: 0, width: 1133, height: 719))
        ]
        var measurements: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let cutout = runtime.bottomCenterOcclusionArea
            measurements.append(["fixture": name, "physical": values(physical), "safe": values(safe),
                "play": values(runtime.playAreaRect), "cutout": values(cutout),
                "screenWidthFraction": cutout.width / physical.width,
                "cornerHeightFraction": cutout.height / runtime.occlusionAreas[0].height])
            let renderer = ImageRenderer(content: scene(runtime: runtime))
            renderer.scale = 1
            let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
            try rep.representation(using: .png, properties: [:])!
                .write(to: out.appendingPathComponent("\(name)-geometry.png"))
        }
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("layout.json"))
    }

    @MainActor static func scene(runtime: RuntimeCanvas) -> some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.07, green: 0.09, blue: 0.12)
            SwiftUI.Path(runtime.runtimePlayArea).fill(.white.opacity(0.07))
            SwiftUI.Path(runtime.towerSlotValidArea).stroke(.cyan.opacity(0.7), lineWidth: 1)
            SwiftUI.Path(runtime.runtimePlayArea).stroke(.pink, lineWidth: 1)
            SwiftUI.Path(runtime.safeInsetsRect).stroke(.green.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            SwiftUI.Path(runtime.hudRect).stroke(.yellow.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
            SwiftUI.Path(runtime.bottomCenterOcclusionArea).fill(.pink.opacity(0.3))
            VStack(spacing: 5) {
                Text("Bottom-center occlusion").font(.system(size: 16, weight: .semibold))
                Text("27.80% of screen width · 20% of corner height").font(.system(size: 12))
                Text("Pink: play boundary · Cyan: tower footprint limit · Yellow: HUD").font(.system(size: 10))
            }.foregroundStyle(.white.opacity(0.85))
                .position(x: runtime.playAreaRect.midX, y: runtime.playAreaRect.midY)
        }.frame(width: runtime.physicalRect.width, height: runtime.physicalRect.height).clipped()
    }
}
