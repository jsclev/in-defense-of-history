import CoreGraphics

/// The encyclopedia shares the game's authored canvas and play-area projection.
/// Wood covers the canvas; the complete scroll and its controls stay in the play area.
public struct TowerEncyclopediaLayout {
    /// Dense encyclopedia cells have no price plaque and use their own shared inset.
    public static let iconInsetFraction: CGFloat = 0.04
    public let backgroundFrame: CGRect
    public let scrollFrame: CGRect
    public let contentFrame: CGRect
    public let gridFrame: CGRect
    public let detailFrame: CGRect
    public let doneFrame: CGRect
    public let cellSide: CGFloat
    public let iconSide: CGFloat
    public let gridGap: CGFloat
    public let columnGap: CGFloat
    public let typeScale: CGFloat

    public init(runtimeCanvas: RuntimeCanvas, doneAspect: CGFloat) {
        let canvas = runtimeCanvas.virtualCanvas
        let projection = LevelMapProjection(playArea: canvas.playAreaRect,
            fitRect: runtimeCanvas.playAreaRect, virtualCanvas: canvas)
        let play = canvas.playAreaRect
        let unit = play.height / 1080
        let scroll = play.insetBy(dx: 8 * unit, dy: 8 * unit)
        // Shallow roll ends leave flat paper close to the top and bottom edges.
        // Keep every grid cell inside that paper while reclaiming its height.
        let content = play.insetBy(dx: 128 * unit, dy: 32 * unit)
        // Adjacent cells share one divider; use the full paper height for icons.
        let gap: CGFloat = 0
        let side = (content.height - 5 * gap) / 6
        let gridWidth = side * 5 + gap * 4
        let separation = 52 * unit
        let doneHeight = max(128 * unit, TouchTarget.minimum / projection.scale)
        let done = CGRect(x: content.maxX - doneHeight * doneAspect, y: content.minY,
                          width: doneHeight * doneAspect, height: doneHeight)
        let detailBottom = done.maxY + 6 * unit
        let details = CGRect(x: content.minX + gridWidth + separation,
                             y: detailBottom,
                             width: content.width - gridWidth - separation,
                             height: content.maxY - detailBottom)
        let grid = CGRect(x: content.minX, y: content.minY,
                          width: gridWidth, height: side * 6 + gap * 5)
        func frame(_ rect: CGRect) -> CGRect { rect.applying(projection.viewTransform) }
        backgroundFrame = frame(CGRect(origin: .zero, size: canvas.size))
        scrollFrame = frame(scroll)
        contentFrame = frame(content)
        gridFrame = frame(grid)
        detailFrame = frame(details)
        doneFrame = frame(done)
        cellSide = projection.viewLength(side)
        iconSide = cellSide * (1 - 2 * Self.iconInsetFraction)
        gridGap = projection.viewLength(gap)
        columnGap = projection.viewLength(separation)
        typeScale = runtimeCanvas.playAreaRect.height / 340
    }
}
