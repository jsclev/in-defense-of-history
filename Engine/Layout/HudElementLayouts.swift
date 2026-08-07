import CoreGraphics

/// Resolved frames for every HUD element, in physical-screen coordinates.
///
/// Each element type here is the complete sizing-and-placement answer for one
/// piece of HUD: construct it from a `ScreenGeometry` (plus whatever facts the
/// logic genuinely needs, like an image's aspect ratio) and read frames off
/// it. Nothing in this file may import SwiftUI or UIKit — image aspects and
/// text strings are inputs, never lookups — so every element is testable by
/// constructing geometry by hand.
///
/// The shared rules all elements inherit:
///   * one scale per screen (`HudScale`), one margin (`HudSizing.hudMargin`)
///   * anchoring via `HudPlacementSolver`: inside the safe area, at least the
///     margin from the physical edge, inset and margin never added
///   * composition via `StackLayout`, so siblings share top/leading edges

/// The speed-up and back-to-campaign buttons in the top-trailing corner.
public struct CornerButtonsLayout: Equatable {
    public let speed: CGRect
    public let pause: CGRect
    /// The two buttons and their gap, as one block.
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

/// The lives counter, money counter and wave line in the top-leading corner.
public struct StatsPanelLayout: Equatable {
    public struct CounterRow: Equatable {
        public let icon: CGRect
        /// Box the value text draws in, top-leading aligned.
        public let valueBox: CGRect
        public let fontSize: CGFloat
    }

    public let lives: CounterRow
    public let money: CounterRow
    /// Backing plates, one per counter group, padded a little beyond the
    /// icon and value they hold.
    public let livesPlate: CGRect
    public let moneyPlate: CGRect
    /// Box the wave line draws in, centred under the counters.
    public let waveBox: CGRect
    public let waveFontSize: CGFloat
    public let bounds: CGRect

    /// Rough line-box height for a font size; exact glyph metrics are the
    /// renderer's business, this only reserves vertical room.
    static let lineHeightFactor: CGFloat = 1.25

    public init(screen: ScreenGeometry, isPortrait: Bool,
                livesIconAspect: CGFloat, moneyIconAspect: CGFloat) {
        let scale = HudScale(viewSize: screen.physical.size).value

        func counterSizes(icon: ScaledDimension, valueWidth: ScaledDimension,
                          aspect: CGFloat, spacing: ScaledDimension) -> StackLayout {
            let h = icon.resolved(at: scale)
            return StackLayout.row(
                [CGSize(width: h * aspect, height: h),
                 CGSize(width: valueWidth.resolved(at: scale), height: h)],
                spacing: spacing.resolved(at: scale))
        }

        let livesRow = counterSizes(icon: HudSizing.livesIcon,
                                    valueWidth: HudSizing.livesValueWidth,
                                    aspect: livesIconAspect,
                                    spacing: HudSizing.livesRowSpacing)
        let moneyRow = counterSizes(icon: HudSizing.moneyIcon,
                                    valueWidth: HudSizing.moneyValueWidth,
                                    aspect: moneyIconAspect,
                                    spacing: HudSizing.moneyRowSpacing)

        let groupSpacing = HudSizing.statSpacing.resolved(at: scale)
        let groups = isPortrait
            ? StackLayout.column([livesRow.size, moneyRow.size], spacing: groupSpacing)
            : StackLayout.row([livesRow.size, moneyRow.size], spacing: groupSpacing)

        let origin = HudPlacementSolver.origin(
            corner: .topLeading,
            margin: HudSizing.hudMargin.resolved(at: scale), in: screen)

        let livesOrigin = CGPoint(x: origin.x + groups.frames[0].minX,
                                  y: origin.y + groups.frames[0].minY)
        let moneyOrigin = CGPoint(x: origin.x + groups.frames[1].minX,
                                  y: origin.y + groups.frames[1].minY)
        lives = CounterRow(icon: livesRow.frames[0].offsetBy(dx: livesOrigin.x, dy: livesOrigin.y),
                           valueBox: livesRow.frames[1].offsetBy(dx: livesOrigin.x, dy: livesOrigin.y),
                           fontSize: HudSizing.livesText.resolved(at: scale))
        money = CounterRow(icon: moneyRow.frames[0].offsetBy(dx: moneyOrigin.x, dy: moneyOrigin.y),
                           valueBox: moneyRow.frames[1].offsetBy(dx: moneyOrigin.x, dy: moneyOrigin.y),
                           fontSize: HudSizing.moneyText.resolved(at: scale))

        let platePad = HudSizing.statPlatePadding.resolved(at: scale)
        livesPlate = lives.icon.union(lives.valueBox).insetBy(dx: -platePad, dy: -platePad)
        moneyPlate = money.icon.union(money.valueBox).insetBy(dx: -platePad, dy: -platePad)

        waveFontSize = HudSizing.waveText.resolved(at: scale)
        let waveHeight = waveFontSize * Self.lineHeightFactor
        let waveGap = HudSizing.statRowSpacing.resolved(at: scale)
        waveBox = CGRect(x: origin.x,
                         y: origin.y + groups.size.height + waveGap,
                         width: groups.size.width,
                         height: waveHeight)
        bounds = CGRect(x: origin.x, y: origin.y,
                        width: groups.size.width,
                        height: groups.size.height + waveGap + waveHeight)
    }
}

/// The campaign map's menu bar in the bottom-trailing corner.
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

/// The done button in the bottom-trailing corner of menu screens.
public struct DoneButtonLayout: Equatable {
    public let frame: CGRect

    /// `scaleOverride` lets a screen with its own internal scale (the
    /// encyclopedia) keep the button proportionate to itself.
    public init(screen: ScreenGeometry, aspect: CGFloat, scaleOverride: CGFloat? = nil) {
        let scale = scaleOverride ?? HudScale(viewSize: screen.physical.size).value
        let height = HudSizing.doneButton.resolved(at: scale)
        frame = HudPlacementSolver.frame(
            size: CGSize(width: height * aspect, height: height),
            corner: .bottomTrailing,
            margin: HudSizing.hudPadding.resolved(at: scale), in: screen)
    }
}

/// The title graphic in the campaign map's top-leading corner.
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
