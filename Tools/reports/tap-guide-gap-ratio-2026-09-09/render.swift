import LevelEditorFormats
import SwiftUI
import AppKit

public struct DebugLayoutGuidesView: View {
    private let runtimeCanvas: RuntimeCanvas
    private let lineThickness: Int = 3

    private let physicalRectDash: [CGFloat] = [16, 9]
    private let safeInsetsRectDash: [CGFloat] = [16, 9]
    private let hudRectDash: [CGFloat] = [16, 9]
    private let playAreaDash: [CGFloat] = [7.935, 10]
    // 40% cyan, 60% gap so the purple guide underneath remains visible.
    private let tapAreaDash: [CGFloat] = [4.8, 7.2]

    private let physicalRectGuideColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let safeInsetsRectGuideColor = Color(red: 0.18, green: 1.0, blue: 0.33)
    private let hudRectGuideColor = Color(red: 1.0, green: 0.8, blue: 0.0)
    private let playAreaGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)
    private let tapAreaGuideColor = Color(red: 0.0, green: 1.0, blue: 1.0)

    public init(runtimeCanvas: RuntimeCanvas) {
        self.runtimeCanvas = runtimeCanvas
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            createRectView(rect: runtimeCanvas.physicalRect,
                           borderColor: physicalRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: physicalRectDash)
            createRectView(rect: runtimeCanvas.safeInsetsRect,
                           borderColor: safeInsetsRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: safeInsetsRectDash)
            createRectView(rect: runtimeCanvas.hudRect,
                           borderColor: hudRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: hudRectDash)
            createPlayAreaView()
            createTapAreaView()
        }
        .allowsHitTesting(false)
    }

    private func createRectView(rect: CGRect,
                                borderColor: Color,
                                borderThickness: Int,
                                borderDash: [CGFloat] = []) -> some View {
        return Rectangle()
            .strokeBorder(borderColor,
                          style: StrokeStyle(lineWidth: CGFloat(borderThickness), dash: borderDash))
            .frame(width: rect.width, height: rect.height)
            .position(
                x: rect.midX,
                y: rect.midY
            )
    }

    private func createPlayAreaView() -> some View {
        let lineStyle = StrokeStyle(lineWidth: CGFloat(lineThickness), dash: playAreaDash)
        
        return SwiftUI.Path(runtimeCanvas.runtimePlayArea)
            .stroke(playAreaGuideColor, style: lineStyle)
    }

    private func createTapAreaView() -> some View {
        let lineStyle = StrokeStyle(lineWidth: CGFloat(lineThickness), dash: tapAreaDash)
        return SwiftUI.Path(runtimeCanvas.runtimeTapArea)
            .stroke(tapAreaGuideColor, style: lineStyle)
    }
}

@main struct TapAreaProof {
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
            ("phone", CGRect(x: 0, y: 0, width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 373)),
            ("tablet", CGRect(x: 0, y: 0, width: 1133, height: 744), CGRect(x: 0, y: 0, width: 1133, height: 719))
        ]
        var data: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let scene = ZStack(alignment: .topLeading) {
                Color(red: 0.09, green: 0.11, blue: 0.14)
                SwiftUI.Path(runtime.runtimePlayArea).fill(.white.opacity(0.04))
                DebugLayoutGuidesView(runtimeCanvas: runtime)
            }.frame(width: physical.width, height: physical.height).clipped()
            for density in (name == "phone" ? [1, 3] : [1]) {
                let renderer = ImageRenderer(content: scene)
                renderer.scale = CGFloat(density)
                let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
                try rep.representation(using: .png, properties: [:])!
                    .write(to: out.appendingPathComponent("\(name)-guides@\(density)x.png"))
            }
            data.append(["fixture": name, "physical": values(physical), "safe": values(safe),
                         "play": values(runtime.playAreaRect), "tapBounds": values(runtime.runtimeTapArea.boundingBoxOfPath),
                         "topInset": runtime.playAreaRect.height * VirtualCanvas.tapAreaTopInsetFraction])
        }
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("layout.json"))
    }
}
