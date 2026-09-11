import AppKit
import SwiftUI
import LevelEditorFormats
import SwiftUI

@available(iOS 26.0, *)
struct HudStatsView: View {
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @ObservedObject private var runner: LevelRunner
    private let runtimeCanvas: RuntimeCanvas
    private let metrics: HudMetrics

    public init(runtimeCanvas: RuntimeCanvas, runner: LevelRunner) {
        self.runtimeCanvas = runtimeCanvas
        self.runner = runner
        metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
    }

    private static let goldTemplate = "9,999"

    private static func dimensions(in runtimeCanvas: RuntimeCanvas) -> (panel: StatsPanelLayout, size: CGSize, waveWidth: CGFloat) {
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        let panel = StatsPanelLayout(
            runtimeCanvas: runtimeCanvas, topBar: TopBarLayout(runtimeCanvas: runtimeCanvas),
            isPortrait: runtimeCanvas.physicalRect.height > runtimeCanvas.physicalRect.width,
            livesIconAspect: HudIcon.aspect(of: "lives_icon_05"),
            moneyIconAspect: HudIcon.aspect(of: "money_icon_12"),
            moneyText: Self.goldTemplate)
        let pad = metrics.statPlatePadding
        // Match the fixed counter frames below so placement and gesture
        // exclusion stay accurate as the live values change.
        let waveWidth = HudSizing.counterValueWidth("99 of 99", fontSize: panel.waveFontSize,
                                                   trailingPad: 2 * pad)
        let width = panel.lives.valueBox.maxX - panel.lives.icon.minX
            + panel.money.valueBox.maxX - panel.money.icon.minX + 6 * pad + waveWidth
        let height = max(panel.lives.icon.height, panel.money.icon.height) + 2 * pad
        return (panel, CGSize(width: width, height: height), waveWidth)
    }

    static func occupiedFrame(runtimeCanvas: RuntimeCanvas, config: HudLayoutConfig) -> CGRect {
        let layout = dimensions(in: runtimeCanvas)
        return config.frame(for: .statsView, size: layout.size, in: runtimeCanvas.hudRect)
    }

    var body: some View {
        let layout = Self.dimensions(in: runtimeCanvas)
        let panel = layout.panel
        let width = layout.size.width
        let height = layout.size.height
        HStack(spacing: metrics.statPlatePadding) {
            counter(icon: "lives_icon_05", value: livesText, row: panel.lives)
                .accessibilityLabel("Lives: \(runner.lives)")
            counter(icon: "money_icon_12", value: goldText, row: panel.money)
                .accessibilityLabel("Money: \(runner.money)")
            counterText(waveText, fontSize: panel.waveFontSize)
                .frame(width: layout.waveWidth, height: height)
                .background(.black.opacity(HudSizing.statPlateOpacity), in: plate)
                .accessibilityLabel("Wave \(runner.currentWaveNumber) of \(runner.waveCount)")
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) {
            if showDebugInfo {
                Text(runner.status)
                    .font(.system(size: Typography.size(13 * metrics.scale)).monospaced())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(.horizontal, 12 * metrics.scale)
                    .padding(.vertical, 6 * metrics.scale)
                    .frame(width: width, alignment: .leading)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8 * metrics.scale))
                    .offset(y: height + metrics.statPlatePadding)
            }
        }
    }

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.statPlateCorner, style: .continuous)
    }

    private var livesText: String { "\(runner.lives)" }

    private var waveText: String { "\(runner.currentWaveNumber) of \(runner.waveCount)" }

    private var goldText: String {
        let money = runner.money
        return money >= 1000
            ? "\(money / 1000),\(String(format: "%03d", money % 1000))"
            : "\(money)"
    }

    private func counter(icon: String, value: String,
                         row: StatsPanelLayout.CounterRow) -> some View {
        HStack(spacing: row.valueBox.minX - row.icon.maxX) {
            Image(nsImage: Proof.art(icon))
                .resizable()
                .scaledToFit()
                .frame(width: row.icon.width, height: row.icon.height)
                .accessibilityHidden(true)
            counterText(value, fontSize: row.fontSize)
                .frame(width: row.valueBox.width, height: row.valueBox.height, alignment: .leading)
        }
        .padding(metrics.statPlatePadding)
        .background(.black.opacity(HudSizing.statPlateOpacity), in: plate)
        .accessibilityElement(children: .ignore)
    }

    private func counterText(_ value: String, fontSize: CGFloat) -> some View {
        Text(value)
            .font(.system(size: Typography.size(fontSize), weight: .black, design: .rounded)
                .monospacedDigit())
            .lineLimit(1)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
    }
}
import SwiftUI

struct HudMetrics {
    let scale: CGFloat

    init(viewSize: CGSize, virtualCanvas: VirtualCanvas) {
        scale = HudScale(viewSize: viewSize, virtualCanvas: virtualCanvas).value
    }

    init(runtimeCanvas: RuntimeCanvas) {
        scale = HudScale(playableHeight: runtimeCanvas.playAreaRect.height).value
    }

    init(scale: CGFloat) {
        self.scale = scale
    }

    var livesIconHeight: CGFloat { HudSizing.livesIcon.resolved(at: scale) }
    var livesTextSize: CGFloat { HudSizing.livesText.resolved(at: scale) }
    var livesValueWidth: CGFloat { HudSizing.livesValueWidth.resolved(at: scale) }
    var livesRowSpacing: CGFloat { HudSizing.livesRowSpacing.resolved(at: scale) }

    var moneyIconHeight: CGFloat { HudSizing.moneyIcon.resolved(at: scale) }
    var moneyTextSize: CGFloat { HudSizing.moneyText.resolved(at: scale) }
    var moneyRowSpacing: CGFloat { HudSizing.moneyRowSpacing.resolved(at: scale) }

    var waveTextSize: CGFloat { HudSizing.waveText.resolved(at: scale) }

    var rangeLegendTextSize: CGFloat { HudSizing.rangeLegendText.resolved(at: scale) }

    var statSpacing: CGFloat { HudSizing.statSpacing.resolved(at: scale) }
    var statRowSpacing: CGFloat { HudSizing.statRowSpacing.resolved(at: scale) }
    var statPanelMargin: CGFloat { HudSizing.statPanelMargin.resolved(at: scale) }
    var statPlatePadding: CGFloat { HudSizing.statPlatePadding.resolved(at: scale) }
    var statPlateCorner: CGFloat { HudSizing.statPlateCorner.resolved(at: scale) }

    var hudPadding: CGFloat { HudSizing.hudPadding.resolved(at: scale) }

    var cornerButtonSize: CGFloat { HudSizing.cornerButton.resolved(at: scale) }
    var cornerButtonSpacing: CGFloat { HudSizing.cornerButtonSpacing.resolved(at: scale) }
    var hudMargin: CGFloat { HudSizing.hudMargin.resolved(at: scale) }

    var menuButtonSize: CGFloat { HudSizing.menuButton.resolved(at: scale) }
    var menuButtonSpacing: CGFloat { HudSizing.menuButtonSpacing.resolved(at: scale) }
}

struct HudIcon: View {
    let name: String
    let height: CGFloat

    var body: some View {
        Image(nsImage: Proof.art(name))
            .resizable()
            .scaledToFit()
            .frame(width: height * Self.aspect(of: name), height: height)
    }

    static func aspect(of name: String) -> CGFloat {
        guard let image = Optional(Proof.art(name)), image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }
}

@MainActor final class LevelRunner: ObservableObject {
    @Published var lives = 20
    @Published var money = 500
    @Published var currentWaveNumber = 1
    var waveCount = 15
    var status = "HUD value fixture"
}
@main struct Proof {
    @MainActor static var density = 1
    @MainActor static func art(_ name: String) -> NSImage {
        let folder = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
        let contents = try! JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String: Any]
        let entries = (contents["images"] as! [[String: Any]]).filter { $0["filename"] != nil }
        let entry = entries.first { $0["scale"] as? String == "\(density)x" } ?? entries[0]
        return NSImage(contentsOf: folder.appendingPathComponent(entry["filename"] as! String))!
    }
    @MainActor static func save<V: View>(_ view: V, _ name: String, _ out: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(density)
        let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name)@\(density)x.png"))
    }
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let db = Db(dbPath: out.appendingPathComponent("fixture.sqlite").path, fullRefresh: false)
        let vc = try db.virtualCanvasDao.get()
        let minimum = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let fixtures: [(String, CGRect, CGRect)] = [
            ("minimum", minimum, minimum),
            ("phone", CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382))]
        var measurements: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let canvas = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let runner = LevelRunner()
            for (state, lives, money, wave, total) in [("start",20,500,1,15),("end",1,9999,15,15),("wide",99,9999,99,99)] {
                runner.lives = lives; runner.money = money; runner.currentWaveNumber = wave; runner.waveCount = total
                let row = HudStatsView(runtimeCanvas: canvas, runner: runner)
                let occupied = HudStatsView.occupiedFrame(runtimeCanvas: canvas, config: .standard)
                for d in [1,2,3] {
                    density = d
                    try save(row, "\(name)-\(state)", out)
                    if state != "wide" {
                        for (terrain, mapName) in [("grass", "level_01_battle_road"), ("snow", "level_008_trenton")] {
                            let scene = ZStack(alignment: .topLeading) {
                                Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/Levels/\(mapName).heic")!).resizable().frame(width: vc.size.width * canvas.scaleFactor, height: vc.size.height * canvas.scaleFactor).position(x: canvas.playAreaRect.midX, y: canvas.playAreaRect.midY)
                                row.position(x: occupied.midX, y: occupied.midY)
                            }.frame(width: physical.width, height: physical.height).clipped()
                            try save(scene, "\(name)-\(state)-\(terrain)", out)
                        }
                    }
                }
                measurements.append(["fixture":name,"state":state,"width":occupied.width,"height":occupied.height,"font":HudMetrics(runtimeCanvas:canvas).waveTextSize])
            }
        }
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("layout.json"))
    }
}
