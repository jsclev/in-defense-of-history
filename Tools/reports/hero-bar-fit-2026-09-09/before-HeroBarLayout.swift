import CoreGraphics

/// A bottom-left HUD row whose overlap with the map stays inside the authored
/// lower-left occlusion. HUD margins consume space; they do not enlarge it.
public struct HeroBarLayout: Equatable {
    public static let buttonCount = 3
    public let buttonSize: CGFloat
    public let buttonSpacing: CGFloat
    public let frame: CGRect

    public init(runtimeCanvas: RuntimeCanvas) {
        let canvas = runtimeCanvas.virtualCanvas
        let occlusion = canvas.lowerLeftOcclusionArea
        let scale = runtimeCanvas.scaleFactor
        let right = runtimeCanvas.playAreaRect.minX
            + (occlusion.maxX - canvas.playAreaRect.minX) * scale
        let top = runtimeCanvas.playAreaRect.minY
            + (canvas.playAreaRect.maxY - occlusion.maxY) * scale
        let hud = runtimeCanvas.hudRect
        let width = max(0, min(occlusion.width * scale, right - hud.minX))
        let height = max(0, min(occlusion.height * scale, hud.maxY - top))
        let sections = CGFloat(Self.buttonCount) + CGFloat(Self.buttonCount - 1) * 0.1
        buttonSize = min(width / sections, height)
        buttonSpacing = buttonSize * 0.1
        frame = CGRect(x: hud.minX, y: hud.maxY - buttonSize,
                       width: sections * buttonSize, height: buttonSize)
    }
}
