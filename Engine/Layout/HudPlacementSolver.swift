import CoreGraphics

/// The corner a piece of chrome is anchored to.
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

/// Decides where anchored chrome — counters, corner buttons, the title, the
/// menu bar — sits on a given screen.
///
/// Two rules, in priority order:
///
/// 1. Chrome is always entirely inside the safe area. This is absolute.
/// 2. Chrome always keeps at least `margin` from the physical screen edge.
///
/// The element starts at the corner it would occupy inside the playable
/// rect, then shifts outward into any spare room the safe area offers, then
/// is clamped back inside the safe area. Because the outward shift stops at
/// `chromeInset` — which is `max(safeAreaInset, margin)` — the second rule
/// holds by construction: where the safe inset is deep it supplies the
/// clearance, and where it is shallow the margin does.
///
/// Deliberately free of SwiftUI so the rules can be exercised directly.
public enum HudPlacementSolver {

    /// The frame for chrome of `size` anchored to `corner`.
    ///
    /// Pass `.zero` for `size` when the element sizes itself and is anchored
    /// to a leading/top corner — only the origin is meaningful there.
    public static func frame(size: CGSize,
                             corner: HudCorner,
                             margin: CGFloat,
                             in geometry: ScreenGeometry) -> CGRect {
        let x = originX(width: size.width, corner: corner, margin: margin, in: geometry)
        let y = originY(height: size.height, corner: corner, margin: margin, in: geometry)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Just the origin, for elements whose size SwiftUI works out itself.
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
            // start inside the playable rect, shift out to the limit, clamp
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
        let inset = g.chromeInset(corner.vertical, margin: margin)
        switch corner.vertical {
        case .top:
            let limit = g.physical.minY + inset
            return max(min(g.playable.minY + margin, limit), g.safe.minY)
        case .bottom:
            let limit = g.physical.maxY - inset
            let bottom = min(max(g.playable.maxY - margin, limit), g.safe.maxY)
            return bottom - height
        case .leading, .trailing:
            return 0
        }
    }
}
