import CoreGraphics

/// Shared two-column roster and right-hand detail geometry for the encyclopedia.
/// Painted artwork keeps the game's authored canvas and play-area projection.
public struct TowerEncyclopediaLayout {
    public static let columns = 2
    public static let iconInsetFraction: CGFloat = 0.04
    public let backgroundFrame: CGRect
    public let scrollFrame: CGRect
    public let contentFrame: CGRect
    public let gridFrame: CGRect
    public let detailFrame: CGRect
    public let doneFrame: CGRect
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
        func frame(_ rect: CGRect) -> CGRect { rect.applying(projection.viewTransform) }
        backgroundFrame = frame(CGRect(origin: .zero, size: canvas.size))
        scrollFrame = frame(play.insetBy(dx: 8 * unit, dy: 8 * unit))
        contentFrame = frame(play.insetBy(dx: 128 * unit, dy: 32 * unit))
            .intersection(runtimeCanvas.safeInsetsRect)
        typeScale = min(1.5, runtimeCanvas.playAreaRect.height / 340)
        let gap = 8 * typeScale
        let doneHeight = max(TouchTarget.minimum, 40 * typeScale)
        doneFrame = CGRect(x: contentFrame.maxX - doneHeight * doneAspect,
                           y: contentFrame.maxY - doneHeight,
                           width: doneHeight * doneAspect, height: doneHeight)
        let bodyHeight = max(0, doneFrame.minY - gap - contentFrame.minY)
        let rosterWidth = contentFrame.width * 0.34
        gridFrame = CGRect(x: contentFrame.minX, y: contentFrame.minY,
                           width: rosterWidth, height: bodyHeight)
        let detailX = gridFrame.maxX + gap
        titleFrame = CGRect(x: detailX, y: contentFrame.minY,
                            width: contentFrame.maxX - detailX, height: 30 * typeScale)
        detailFrame = CGRect(x: detailX, y: titleFrame.maxY + 4 * typeScale,
                             width: titleFrame.width,
                             height: max(0, gridFrame.maxY - titleFrame.maxY - 4 * typeScale))
        gridGap = 0
        cellSize = CGSize(width: rosterWidth / CGFloat(Self.columns),
                          height: max(TouchTarget.minimum, 80 * typeScale))
        iconSide = min(cellSize.width, cellSize.height) * (1 - 2 * Self.iconInsetFraction)
    }
}
