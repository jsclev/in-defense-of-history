import SwiftUI

@available(iOS 26.0, *)
struct HudStatsView: View {
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @ObservedObject private var runner: LevelRunner
    private let runtimeCanvas: RuntimeCanvas
    private let metrics: HudMetrics
    private let isPortrait: Bool

    public init(runtimeCanvas: RuntimeCanvas, runner: LevelRunner) {
        self.runtimeCanvas = runtimeCanvas
        self.runner = runner
        metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        isPortrait = runtimeCanvas.physicalRect.height > runtimeCanvas.physicalRect.width
    }

    private struct Slot {
        let midX: CGFloat
        let midY: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private static let panelAssetName = "stats_panel_bg"
    private static let livesSlot = Slot(midX: 0.2367, midY: 0.5709, width: 0.1865, height: 0.5631)
    private static let moneySlot = Slot(midX: 0.5878, midY: 0.5709, width: 0.1994, height: 0.5631)
    private static let waveSlot = Slot(midX: 0.9065, midY: 0.5709, width: 0.1228, height: 0.5631)

    private static let livesTemplate = "99"
    private static let goldTemplate = "9,999"
    private static let waveTemplate = "99"

    private static let ink = Color(red: 0.22, green: 0.15, blue: 0.07)
    private static let stripScale: CGFloat = 0.81
    private static let stripLift: CGFloat = 0.08

    var body: some View {
        let panel = StatsPanelLayout(
            runtimeCanvas: runtimeCanvas, topBar: TopBarLayout(runtimeCanvas: runtimeCanvas), isPortrait: isPortrait,
            livesIconAspect: HudIcon.aspect(of: "lives_icon_05"),
            moneyIconAspect: HudIcon.aspect(of: "money_icon_12"),
            moneyText: Self.goldTemplate)
        let aspect = HudIcon.aspect(of: Self.panelAssetName)
        let width = stripWidth(panel: panel) * Self.stripScale
        let height = width / aspect
        let lift = height * Self.stripLift
        VStack(alignment: .leading, spacing: metrics.statPlatePadding) {
            ZStack {
                Image(Self.panelAssetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: width, height: height)
                    .position(x: width / 2, y: height / 2 - lift)
                slot(livesText, fontSize: panel.lives.fontSize, in: Self.livesSlot,
                     width: width, height: height, lift: lift)
                slot(goldText, fontSize: panel.money.fontSize, in: Self.moneySlot,
                     width: width, height: height, lift: lift)
                slot(waveText, fontSize: panel.waveFontSize, in: Self.waveSlot,
                     width: width, height: height, lift: lift)
            }
            .frame(width: width, height: height)

            if showDebugInfo {
                Text(runner.status)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func stripWidth(panel: StatsPanelLayout) -> CGFloat {
        let pad = HudSizing.counterValueTrailingPad.resolved(at: metrics.scale)
        func demand(_ template: String, _ fontSize: CGFloat, _ slot: Slot) -> CGFloat {
            HudSizing.counterValueWidth(template, fontSize: fontSize, trailingPad: pad) / slot.width
        }
        return max(demand(Self.livesTemplate, panel.lives.fontSize, Self.livesSlot),
                   max(demand(Self.goldTemplate, panel.money.fontSize, Self.moneySlot),
                       demand(Self.waveTemplate, panel.waveFontSize, Self.waveSlot)))
    }

    private var livesText: String { "\(runner.lives)" }

    private var waveText: String { "\(runner.currentWaveNumber)" }

    private var goldText: String {
        let money = runner.money
        return money >= 1000
            ? "\(money / 1000),\(String(format: "%03d", money % 1000))"
            : "\(money)"
    }

    private func slot(_ value: String, fontSize: CGFloat, in slot: Slot,
                      width: CGFloat, height: CGFloat, lift: CGFloat) -> some View {
        Text(value)
            .font(.system(size: Typography.size(fontSize), weight: .black, design: .rounded)
                .monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Self.ink)
            .frame(width: width * slot.width, height: height * slot.height)
            .position(x: width * slot.midX, y: height * slot.midY - lift)
    }
}
