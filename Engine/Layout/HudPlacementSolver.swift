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
                             in geometry: ScreenGeometry) -> CGRect {
        let x = originX(width: size.width, corner: corner, margin: margin, in: geometry)
        let y = originY(height: size.height, corner: corner, margin: margin, in: geometry)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    public static func origin(size: CGSize = .zero,
                              corner: HudCorner,
                              margin: CGFloat,
                              in geometry: ScreenGeometry) -> CGPoint {
        frame(size: size, corner: corner, margin: margin, in: geometry).origin
    }

    public static func bottomLineFrame(size: CGSize,
                                       corner: HudCorner,
                                       margin: CGFloat,
                                       in geometry: ScreenGeometry) -> CGRect {
        let x = originX(width: size.width, corner: corner, margin: margin, in: geometry)
        return CGRect(x: x,
                      y: geometry.maxY - size.height,
                      width: size.width,
                      height: size.height)
    }

    private static func originX(width: CGFloat, corner: HudCorner,
                                margin: CGFloat, in g: ScreenGeometry) -> CGFloat {
//        let inset = g.chromeInset(corner.horizontal, margin: margin)
        let inset = g.safeInsetsRect.minX

        switch corner.horizontal {
        case .leading:
            let limit = g.physicalRect.minX + inset
            return max(min(g.playAreaRect.minX + margin, limit), g.safeInsetsRect.minX)
        case .trailing:
            let limit = g.physicalRect.maxX - inset
            let right = min(max(g.playAreaRect.maxX - margin, limit), g.safeInsetsRect.maxX)
            return right - width
        case .top, .bottom:
            return 0
        }
    }

    private static func originY(height: CGFloat, corner: HudCorner,
                                margin: CGFloat, in g: ScreenGeometry) -> CGFloat {
        switch corner.vertical {
        case .top:
            let limit = g.physicalRect.minY + g.safeInsetsRect.minY
//            let limit = g.physical.minY + g.chromeInset(.top, margin: margin)

            return max(min(g.playAreaRect.minY + margin, limit), g.safeInsetsRect.minY)
        case .bottom:
            return max(g.playAreaRect.maxY, g.safeInsetsRect.maxY) - margin - height
        case .leading, .trailing:
            return 0
        }
    }
}
