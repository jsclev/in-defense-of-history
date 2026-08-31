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

    var body: some View {
        let panel = StatsPanelLayout(
            runtimeCanvas: runtimeCanvas, topBar: TopBarLayout(runtimeCanvas: runtimeCanvas), isPortrait: isPortrait,
            livesIconAspect: HudIcon.aspect(of: "lives_icon_05"),
            moneyIconAspect: HudIcon.aspect(of: "money_icon_12"),
            moneyText: Self.goldTemplate)
        VStack(alignment: .leading, spacing: metrics.statPlatePadding) {
            VStack(spacing: metrics.statPlatePadding) {
                HStack(spacing: metrics.statPlatePadding) {
                    counter(icon: "lives_icon_05", value: "\(runner.lives)",
                            template: "\(runner.lives)", row: panel.lives)
                    counter(icon: "money_icon_12", value: goldText,
                            template: Self.goldTemplate, row: panel.money)
                }
                counterText("Wave \(runner.waveCount) of \(runner.waveCount)",
                            fontSize: panel.waveFontSize)
                    .hidden()
                    .overlay(counterText("Wave \(runner.currentWaveNumber) of \(runner.waveCount)",
                                         fontSize: panel.waveFontSize))
                    .padding(.horizontal, metrics.statPlatePadding * 1.4)
                    .padding(.vertical, metrics.statPlatePadding * 0.6)
                    .background(.black.opacity(HudSizing.statPlateOpacity), in: plate)
            }
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

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.statPlateCorner, style: .continuous)
    }

    private static let goldTemplate = "9,999"

    private var goldText: String {
        let money = runner.money
        return money >= 1000
            ? "\(money / 1000),\(String(format: "%03d", money % 1000))"
            : "\(money)"
    }

    private func counter(icon: String, value: String, template: String,
                         row: StatsPanelLayout.CounterRow) -> some View {
        HStack(spacing: row.valueBox.minX - row.icon.maxX) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: row.icon.width, height: row.icon.height)
            counterText(template, fontSize: row.fontSize)
                .hidden()
                .overlay(alignment: .leading) {
                    counterText(value, fontSize: row.fontSize)
                }
        }
        .padding(metrics.statPlatePadding)
        .background(.black.opacity(HudSizing.statPlateOpacity), in: plate)
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
