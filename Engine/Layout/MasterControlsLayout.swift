import CoreGraphics

/// A top-right HUD row that uses the corner occlusion and any space between
/// the HUD edges and the map, while keeping its map overlap in the occlusion.
public struct MasterControlsLayout: Equatable {
    public static let buttonCount = 2
    public let buttonSize: CGFloat
    public let buttonSpacing: CGFloat
    public let frame: CGRect

    public init(runtimeCanvas: RuntimeCanvas) {
        let canvas = runtimeCanvas.virtualCanvas
        let occlusion = canvas.upperRightOcclusionArea
        let scale = runtimeCanvas.scaleFactor
        let left = runtimeCanvas.playAreaRect.minX
            + (occlusion.minX - canvas.playAreaRect.minX) * scale
        let bottom = runtimeCanvas.playAreaRect.minY
            + (canvas.playAreaRect.maxY - occlusion.minY) * scale
        let hud = runtimeCanvas.hudRect
        // The HUD supplies the top/right edges; the occlusion supplies the
        // bottom/left edges. Include usable space outside the map, clipped to HUD.
        let width = max(0, hud.maxX - max(left, hud.minX))
        let height = max(0, min(bottom, hud.maxY) - hud.minY)
        let sections = CGFloat(Self.buttonCount) + CGFloat(Self.buttonCount - 1) * 0.1
        buttonSize = min(width / sections, height)
        buttonSpacing = buttonSize * 0.1
        frame = CGRect(x: hud.maxX - sections * buttonSize, y: hud.minY,
                       width: sections * buttonSize, height: buttonSize)
    }
}
