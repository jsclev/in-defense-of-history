import CoreGraphics

/// Reserves space for a screen's navigation control before laying out its art.
public struct MenuContentLayout: Equatable {
    public let frame: CGRect

    public init(runtimeCanvas: RuntimeCanvas, footer: CGRect) {
        let play = runtimeCanvas.playAreaRect
        let gap = HudSizing.hudPadding.resolved(
            at: HudScale(playableHeight: play.height).value)
        frame = CGRect(x: play.minX, y: play.minY, width: play.width,
                       height: max(0, min(play.maxY, footer.minY - gap) - play.minY))
    }
}
