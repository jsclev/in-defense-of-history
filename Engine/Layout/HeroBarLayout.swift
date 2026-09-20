import CoreGraphics

/// Sizes and anchors the complete row inside its reserved HUD corner.
public struct HeroBarLayout: Equatable {
    public static let buttonCount = 3
    public let buttonSize: CGFloat
    public let buttonSpacing: CGFloat
    public let frame: CGRect

    public init(runtimeCanvas: RuntimeCanvas, location: HudLocation = .southWest) {
        let row = HudButtonRowLayout(area: runtimeCanvas.hudPlayArea,
                                     location: location, count: Self.buttonCount)
        buttonSize = row.buttonSize
        buttonSpacing = row.buttonSpacing
        frame = row.frame
    }
}
