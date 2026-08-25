import CoreGraphics

public enum HudCorner {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    var horizontal: ScreenEdge {
        switch self {
        case .topLeading, .bottomLeading: return .leading
        case .topTrailing, .bottomTrailing: return .trailing
        }
    }

    var vertical: ScreenEdge {
        switch self {
        case .topLeading, .topTrailing: return .top
        case .bottomLeading, .bottomTrailing: return .bottom
        }
    }
}

public enum HudPlacementSolver {

    public static func frame(size: CGSize,
                             corner: HudCorner,
                             margin: CGFloat,
                             in runtimeCanvas: RuntimeCanvas) -> CGRect {
        let x = originX(width: size.width, corner: corner, margin: margin, in: runtimeCanvas)
        let y = originY(height: size.height, corner: corner, margin: margin, in: runtimeCanvas)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    public static func origin(size: CGSize = .zero,
                              corner: HudCorner,
                              margin: CGFloat,
                              in runtimeCanvas: RuntimeCanvas) -> CGPoint {
        frame(size: size, corner: corner, margin: margin, in: runtimeCanvas).origin
    }

    public static func bottomLineFrame(size: CGSize,
                                       corner: HudCorner,
                                       margin: CGFloat,
                                       in runtimeCanvas: RuntimeCanvas) -> CGRect {
        let x = originX(width: size.width, corner: corner, margin: margin, in: runtimeCanvas)
        return CGRect(x: x,
                      y: runtimeCanvas.maxY - size.height,
                      width: size.width,
                      height: size.height)
    }

    private static func originX(width: CGFloat, corner: HudCorner,
                                margin: CGFloat, in runtimeCanvas: RuntimeCanvas) -> CGFloat {
        let inset = runtimeCanvas.safeInsetsRect.minX

        switch corner.horizontal {
        case .leading:
            let limit = runtimeCanvas.physicalRect.minX + inset
            return max(min(runtimeCanvas.playAreaRect.minX + margin, limit), runtimeCanvas.safeInsetsRect.minX)
        case .trailing:
            let limit = runtimeCanvas.physicalRect.maxX - inset
            let right = min(max(runtimeCanvas.playAreaRect.maxX - margin, limit), runtimeCanvas.safeInsetsRect.maxX)
            return right - width
        case .top, .bottom:
            return 0
        }
    }

    private static func originY(height: CGFloat, corner: HudCorner,
                                margin: CGFloat, in runtimeCanvas: RuntimeCanvas) -> CGFloat {
        switch corner.vertical {
        case .top:
            let limit = runtimeCanvas.physicalRect.minY + runtimeCanvas.safeInsetsRect.minY

            return max(min(runtimeCanvas.playAreaRect.minY + margin, limit), runtimeCanvas.safeInsetsRect.minY)
        case .bottom:
            return max(runtimeCanvas.playAreaRect.maxY, runtimeCanvas.safeInsetsRect.maxY) - margin - height
        case .leading, .trailing:
            return 0
        }
    }
}
