import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

public struct ScreenGeometry {
    public let virtualCanvas: VirtualCanvas
    public let physicalRect: CGRect
    public let safeInsetsRect: CGRect
    public let playAreaRect: CGRect
    public let playArea: CGPath
    public let scaleFactor: CGFloat

    public init(virtualCanvas: VirtualCanvas,
                physicalRect: CGRect,
                safeInsetsRect: CGRect) {
        self.virtualCanvas = virtualCanvas
        self.physicalRect = physicalRect
        self.safeInsetsRect = safeInsetsRect

        let virtualPlayArea = virtualCanvas.playAreaRect
        scaleFactor = min(safeInsetsRect.width / virtualPlayArea.width,
                          safeInsetsRect.height / virtualPlayArea.height)

        let width = virtualPlayArea.width * scaleFactor
        let height = virtualPlayArea.height * scaleFactor
        playAreaRect = CGRect(x: safeInsetsRect.midX - width / 2,
                          y: safeInsetsRect.midY - height / 2,
                          width: width, height: height)
        
        var transform = CGAffineTransform(
            a: scaleFactor,
            b: 0,
            c: 0,
            d: -scaleFactor,
            tx: playAreaRect.minX - virtualPlayArea.minX * scaleFactor,
            ty: playAreaRect.minY + virtualPlayArea.maxY * scaleFactor)
        
        playArea = virtualCanvas.playAreaShape.copy(using: &transform)
            ?? virtualCanvas.playAreaShape
    }
}
