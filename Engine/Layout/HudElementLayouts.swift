import CoreGraphics

public struct CornerButtonsLayout: Equatable {
    public let speed: CGRect
    public let pause: CGRect
    public let block: CGRect

    public init(screen: ScreenGeometry) {
        let scale = HudScale(viewSize: screen.physical.size).value
        let side = HudSizing.cornerButton.resolved(at: scale)
        let item = CGSize(width: side, height: side)
        let row = StackLayout.row([item, item],
                                  spacing: HudSizing.cornerButtonSpacing.resolved(at: scale))
        let anchored = HudPlacementSolver.frame(
            size: row.size, corner: .topTrailing,
            margin: HudSizing.hudMargin.resolved(at: scale), in: screen)
        let frames = row.placed(at: anchored.origin)
        speed = frames[0]
        pause = frames[1]
        block = anchored
    }
}

public struct StatsPanelLayout: Equatable {
    public struct CounterRow: Equatable {
        public let icon: CGRect
        public let valueBox: CGRect
        public let fontSize: CGFloat
    }

    public let lives: CounterRow
    public let money: CounterRow
    public let livesPlate: CGRect
    public let moneyPlate: CGRect
    public let waveBox: CGRect
    public let waveFontSize: CGFloat
    public let bounds: CGRect

    static let lineHeightFactor: CGFloat = 1.25

    public init(screen: ScreenGeometry, isPortrait: Bool,
                livesIconAspect: CGFloat, moneyIconAspect: CGFloat,
                moneyText: String) {
        let scale = HudScale(viewSize: screen.physical.size).value

        func counterSizes(icon: ScaledDimension, valueWidth: CGFloat,
                          aspect: CGFloat, spacing: ScaledDimension) -> StackLayout {
            let h = icon.resolved(at: scale)
            return StackLayout.row(
                [CGSize(width: h * aspect, height: h),
                 CGSize(width: valueWidth, height: h)],
                spacing: spacing.resolved(at: scale))
        }

        let moneyFontSize = HudSizing.moneyText.resolved(at: scale)
        let livesRow = counterSizes(icon: HudSizing.livesIcon,
                                    valueWidth: HudSizing.livesValueWidth.resolved(at: scale),
                                    aspect: livesIconAspect,
                                    spacing: HudSizing.livesRowSpacing)
        let moneyRow = counterSizes(
            icon: HudSizing.moneyIcon,
            valueWidth: HudSizing.counterValueWidth(
                moneyText,
                fontSize: moneyFontSize,
                trailingPad: HudSizing.counterValueTrailingPad.resolved(at: scale)),
            aspect: moneyIconAspect,
            spacing: HudSizing.moneyRowSpacing)

        let groupSpacing = HudSizing.statSpacing.resolved(at: scale)
        let groups = isPortrait
            ? StackLayout.column([livesRow.size, moneyRow.size], spacing: groupSpacing)
            : StackLayout.row([livesRow.size, moneyRow.size], spacing: groupSpacing)

        let origin = HudPlacementSolver.origin(
            corner: .topLeading,
            margin: HudSizing.statPanelMargin.resolved(at: scale), in: screen)

        let livesOrigin = CGPoint(x: origin.x + groups.frames[0].minX,
                                  y: origin.y + groups.frames[0].minY)
        let moneyOrigin = CGPoint(x: origin.x + groups.frames[1].minX,
                                  y: origin.y + groups.frames[1].minY)
        lives = CounterRow(icon: livesRow.frames[0].offsetBy(dx: livesOrigin.x, dy: livesOrigin.y),
                           valueBox: livesRow.frames[1].offsetBy(dx: livesOrigin.x, dy: livesOrigin.y),
                           fontSize: HudSizing.livesText.resolved(at: scale))
        money = CounterRow(icon: moneyRow.frames[0].offsetBy(dx: moneyOrigin.x, dy: moneyOrigin.y),
                           valueBox: moneyRow.frames[1].offsetBy(dx: moneyOrigin.x, dy: moneyOrigin.y),
                           fontSize: moneyFontSize)

        let platePad = HudSizing.statPlatePadding.resolved(at: scale)
        livesPlate = lives.icon.union(lives.valueBox).insetBy(dx: -platePad, dy: -platePad)
        moneyPlate = money.icon.union(money.valueBox).insetBy(dx: -platePad, dy: -platePad)

        waveFontSize = HudSizing.waveText.resolved(at: scale)
        let waveHeight = waveFontSize * Self.lineHeightFactor
        let waveGap = HudSizing.statRowSpacing.resolved(at: scale)
        let plateSpan = livesPlate.union(moneyPlate)
        waveBox = CGRect(x: plateSpan.minX,
                         y: origin.y + groups.size.height + waveGap,
                         width: plateSpan.width,
                         height: waveHeight)
        bounds = CGRect(x: plateSpan.minX, y: origin.y,
                        width: plateSpan.width,
                        height: groups.size.height + waveGap + waveHeight)
    }
}

public struct MenuBarLayout: Equatable {
    public let itemFrames: [CGRect]
    public let bar: CGRect

    public init(screen: ScreenGeometry, itemCount: Int) {
        let scale = HudScale(viewSize: screen.physical.size).value
        let side = HudSizing.menuButton.resolved(at: scale)
        let item = CGSize(width: side, height: side)
        let row = StackLayout.row(Array(repeating: item, count: max(itemCount, 0)),
                                  spacing: HudSizing.menuButtonSpacing.resolved(at: scale))
        let anchored = HudPlacementSolver.frame(
            size: row.size, corner: .bottomTrailing,
            margin: HudSizing.hudMargin.resolved(at: scale), in: screen)
        itemFrames = row.placed(at: anchored.origin)
        bar = anchored
    }
}

public struct DoneButtonLayout: Equatable {
    public let frame: CGRect

    public init(screen: ScreenGeometry, aspect: CGFloat, scaleOverride: CGFloat? = nil) {
        let scale = scaleOverride ?? HudScale(viewSize: screen.physical.size).value
        let height = HudSizing.doneButton.resolved(at: scale)
        frame = HudPlacementSolver.frame(
            size: CGSize(width: height * aspect, height: height),
            corner: .bottomTrailing,
            margin: HudSizing.hudPadding.resolved(at: scale), in: screen)
    }
}

public struct TitleLayout: Equatable {
    public let frame: CGRect

    public init(screen: ScreenGeometry, aspect: CGFloat) {
        let scale = HudScale(viewSize: screen.physical.size).value
        let width = min(screen.physical.width * HudSizing.titleWidthFraction,
                        HudSizing.titleMaxWidth)
        frame = HudPlacementSolver.frame(
            size: CGSize(width: width, height: width * aspect),
            corner: .topLeading,
            margin: HudSizing.titleMargin.resolved(at: scale), in: screen)
    }
}
