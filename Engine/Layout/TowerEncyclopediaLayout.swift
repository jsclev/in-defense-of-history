import CoreGraphics

/// The encyclopedia shares the game's authored canvas and play-area projection.
/// Wood covers the canvas; the complete scroll and its controls stay in the play area.
public struct TowerEncyclopediaLayout {
    public static let rows = 5
    public static let columns = 6
    /// Dense encyclopedia cells have no price plaque and use their own shared inset.
    public static let iconInsetFraction: CGFloat = 0.04
    public let backgroundFrame: CGRect
    public let scrollFrame: CGRect
    public let contentFrame: CGRect
    public let gridFrame: CGRect
    public let detailFrame: CGRect
    public let doneFrame: CGRect
    public let backFrame: CGRect
    public let titleFrame: CGRect
    public let cellSize: CGSize
    public let iconSide: CGFloat
    public let gridGap: CGFloat
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
        // Each family reads left to right. The roster and details occupy
        // separate screens. Done stays beneath the list; details have a header.
        let gap: CGFloat = 0
        let doneHeight = max(128 * unit, TouchTarget.minimum / projection.scale)
        let done = CGRect(x: content.maxX - doneHeight * doneAspect, y: content.minY,
                          width: doneHeight * doneAspect, height: doneHeight)
        let bodyTop = done.maxY + 6 * unit
        let body = CGRect(x: content.minX, y: bodyTop,
                          width: content.width, height: content.maxY - bodyTop)
        // Authored coordinates point upward, so maxY is the visible top edge.
        let back = CGRect(x: content.minX, y: content.maxY - doneHeight, width: doneHeight, height: doneHeight)
        let title = CGRect(x: back.maxX + 16 * unit, y: back.minY,
                           width: content.width - 2 * (doneHeight + 16 * unit), height: doneHeight)
        let cellWidth = body.width / CGFloat(Self.columns)
        let cellHeight = body.height / CGFloat(Self.rows)
        func frame(_ rect: CGRect) -> CGRect { rect.applying(projection.viewTransform) }
        backgroundFrame = frame(CGRect(origin: .zero, size: canvas.size))
        scrollFrame = frame(scroll)
        contentFrame = frame(content)
        gridFrame = frame(body)
        detailFrame = frame(CGRect(origin: content.origin, size: body.size))
        doneFrame = frame(done)
        backFrame = frame(back)
        titleFrame = frame(title)
        cellSize = CGSize(width: projection.viewLength(cellWidth), height: projection.viewLength(cellHeight))
        iconSide = min(cellSize.width, cellSize.height) * (1 - 2 * Self.iconInsetFraction)
        gridGap = projection.viewLength(gap)
        typeScale = runtimeCanvas.playAreaRect.height / 340
    }
}
