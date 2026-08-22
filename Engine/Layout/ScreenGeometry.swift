import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

public struct ScreenGeometry: Equatable {
    public let physicalRect: CGRect
    public let safeInsetsRect: CGRect
    public let playAreaRect: CGRect
    public let scaleFactor: CGFloat

    public init(physicalRect: CGRect,
                safeInsetsRect: CGRect,
                virtualCanvas: VirtualCanvas) {
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
    }
}
