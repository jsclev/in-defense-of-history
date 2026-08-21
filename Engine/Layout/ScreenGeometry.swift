import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

public struct ScreenGeometry: Equatable {
    public let physical: CGRect
    public let safe: CGRect
    public let playable: CGRect

    /// Where the play area lands on this screen. Not computed here: the
    /// canvas spec owns play-area geometry and supplies this rect.
//    public let playable: CGRect

    public init(physicalRect: CGRect,
                safeInsetsRect: CGRect,
                canvasSpec: CanvasSpec) {
        self.physical = physicalRect
        self.safe = safeInsetsRect
        self.playable = canvasSpec.playableRect(in: physicalRect.size)
    }

//    public func safeAreaInset(_ edge: ScreenEdge) -> CGFloat {
//        switch edge {
//        case .leading:  return safe.minX - physical.minX
//        case .trailing: return physical.maxX - safe.maxX
//        case .top:      return safe.minY - physical.minY
//        case .bottom:   return physical.maxY - safe.maxY
//        }
//    }
//
//    public func chromeInset(_ edge: ScreenEdge, margin: CGFloat) -> CGFloat {
//        max(safeAreaInset(edge), margin)
//    }
}
