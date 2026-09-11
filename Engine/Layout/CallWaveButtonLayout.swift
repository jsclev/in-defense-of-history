import CoreGraphics

/// Resolves the button's geometry only. Authored centers are never moved to
/// avoid other UI; the level editor owns placement and the view owns rendering.
public final class CallWaveButtonLayout {
    public static let imageName = "hud_call_wave"
    public let frame: CGRect
    public let countdownFontSize: CGFloat
    public let countdownHorizontalPadding: CGFloat
    public let countdownVerticalPadding: CGFloat

    public init(position: Point, runtimeCanvas: RuntimeCanvas) {
        let scale = HudScale(playableHeight: runtimeCanvas.playAreaRect.height).value
        let side = HudSizing.callWaveButton.resolved(at: scale)
        let projection = LevelMapProjection(playArea: runtimeCanvas.virtualCanvas.playAreaRect,
            fitRect: runtimeCanvas.playAreaRect, virtualCanvas: runtimeCanvas.virtualCanvas)
        let center = projection.viewPoint(CGPoint(x: position.x, y: position.y))
        frame = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        countdownFontSize = Typography.size(side * 0.22)
        countdownHorizontalPadding = side * 5 / TouchTarget.minimum
        countdownVerticalPadding = side * 2 / TouchTarget.minimum
    }

}
