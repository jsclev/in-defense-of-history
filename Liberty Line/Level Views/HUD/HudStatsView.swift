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
    private static let plateOpacity = 0.72
    private static let leadingPaddingMultiplier: CGFloat = 3
    // Scale the resolved artwork, text, padding and corners together by exactly 12%.
    private static let displayScale: CGFloat = 0.88

    private static func dimensions(in runtimeCanvas: RuntimeCanvas) -> (panel: StatsPanelLayout, size: CGSize, waveWidth: CGFloat, spacing: CGFloat, plateHeight: CGFloat) {
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        let panel = StatsPanelLayout(
            runtimeCanvas: runtimeCanvas, topBar: TopBarLayout(runtimeCanvas: runtimeCanvas),
            isPortrait: runtimeCanvas.physicalRect.height > runtimeCanvas.physicalRect.width,
            livesIconAspect: HudIcon.aspect(of: "lives_icon_05"),
            moneyIconAspect: HudIcon.aspect(of: "money_icon_12"),
            moneyText: Self.goldTemplate)
        let pad = metrics.statPlatePadding
        let spacing = 2.5 * pad
        // Match the fixed counter frames below so placement and gesture
        // exclusion stay accurate as the live values change.
        let waveWidth = HudSizing.counterValueWidth("99 of 99", fontSize: panel.money.fontSize,
                                                   trailingPad: 2 * pad)
        let counterRowWidth = panel.lives.valueBox.maxX - panel.lives.icon.minX
            + panel.money.valueBox.maxX - panel.money.icon.minX
            + (2 + 2 * Self.leadingPaddingMultiplier) * pad + spacing
        let plateHeight = max(panel.lives.icon.height, panel.money.icon.height) + 2 * pad
        let size = CGSize(width: max(counterRowWidth, waveWidth), height: 2 * plateHeight + spacing)
        return (panel, size, waveWidth, spacing, plateHeight)
    }

    static func occupiedFrame(runtimeCanvas: RuntimeCanvas, config: HudLayoutConfig) -> CGRect {
        let layout = dimensions(in: runtimeCanvas)
        let size = CGSize(width: layout.size.width * Self.displayScale,
                          height: layout.size.height * Self.displayScale)
        return config.frame(for: .statsView, size: size, in: runtimeCanvas.hudRect)
    }

    var body: some View {
        let layout = Self.dimensions(in: runtimeCanvas)
        let panel = layout.panel
        let width = layout.size.width * Self.displayScale
        let height = layout.size.height * Self.displayScale
        VStack(alignment: .center, spacing: layout.spacing) {
            HStack(spacing: layout.spacing) {
                counter(icon: "lives_icon_05", value: livesText, row: panel.lives, plateHeight: layout.plateHeight)
                    .accessibilityLabel("Lives: \(runner.lives)")
                counter(icon: "money_icon_12", value: goldText, row: panel.money, plateHeight: layout.plateHeight)
                    .accessibilityLabel("Money: \(runner.money)")
            }
            counterText(waveText, fontSize: panel.money.fontSize)
                .frame(width: layout.waveWidth, height: layout.plateHeight)
                .background(.black.opacity(Self.plateOpacity), in: plate)
                .accessibilityLabel("Wave \(runner.currentWaveNumber) of \(runner.waveCount)")
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .scaleEffect(Self.displayScale)
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
        RoundedRectangle(cornerRadius: 1.5 * metrics.statPlateCorner, style: .continuous)
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
                         row: StatsPanelLayout.CounterRow, plateHeight: CGFloat) -> some View {
        HStack(spacing: row.valueBox.minX - row.icon.maxX) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: row.icon.width, height: row.icon.height)
                .accessibilityHidden(true)
            counterText(value, fontSize: row.fontSize)
                .frame(width: row.valueBox.width, height: row.valueBox.height, alignment: .leading)
        }
        // Give the rounded leading cap a deliberate, visible margin.
        .padding(.leading, Self.leadingPaddingMultiplier * metrics.statPlatePadding)
        .padding(.trailing, metrics.statPlatePadding)
        .frame(height: plateHeight)
        .background(.black.opacity(Self.plateOpacity), in: plate)
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
