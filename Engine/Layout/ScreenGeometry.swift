import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

public struct ScreenGeometry: Equatable {
    public let physical: CGRect
    public let safe: CGRect
    public let playable: CGRect

    public init(physicalRect: CGRect,
                safeInsetsRect: CGRect,
                virtualCanvas: VirtualCanvas) {
        self.physical = physicalRect
        self.safe = safeInsetsRect
        self.playable = virtualCanvas.playableRect(in: physicalRect.size)
    }
}
