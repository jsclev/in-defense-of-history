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

    private static func originX(width: CGFloat, corner: HudCorner,
                                margin: CGFloat, in g: ScreenGeometry) -> CGFloat {
        let inset = g.chromeInset(corner.horizontal, margin: margin)
        switch corner.horizontal {
        case .leading:
            let limit = g.physical.minX + inset
            return max(min(g.playable.minX + margin, limit), g.safe.minX)
        case .trailing:
            let limit = g.physical.maxX - inset
            let right = min(max(g.playable.maxX - margin, limit), g.safe.maxX)
            return right - width
        case .top, .bottom:
            return 0
        }
    }

    private static func originY(height: CGFloat, corner: HudCorner,
                                margin: CGFloat, in g: ScreenGeometry) -> CGFloat {
        switch corner.vertical {
        case .top:
            let limit = g.physical.minY + g.chromeInset(.top, margin: margin)
            return max(min(g.playable.minY + margin, limit), g.safe.minY)
        case .bottom:
            return max(g.playable.maxY, g.safe.maxY) - margin - height
        case .leading, .trailing:
            return 0
        }
    }
}
