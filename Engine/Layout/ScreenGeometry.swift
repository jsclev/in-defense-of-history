import CoreGraphics

/// Which edge of the screen a measurement is taken from.
public enum ScreenEdge {
    case leading, trailing, top, bottom
}

/// The three rectangles every screen is laid out against, in one value.
///
/// - `physical` is the whole display: the full-bleed bounds, origin zero.
/// - `safe` is the system safe area, inset from the physical bounds by the
///   notch, status bar, home indicator and rounded corners.
/// - `playable` is the 16:9 region that is guaranteed visible on every
///   device. It is centred in the physical bounds, and is the coordinate
///   space all gameplay is authored against.
///
/// The three are independent: `safe` can be wider than `playable` (most
/// phones) or shorter than it (most tablets), and either can extend past the
/// other on any edge. Nothing here assumes an ordering between them.
///
/// Deliberately free of SwiftUI so the layout rules can be exercised without
/// a view hierarchy.
public struct ScreenGeometry: Equatable {
    public let physical: CGRect
    public let safe: CGRect
    public let playable: CGRect

    public init(fullSize: CGSize,
                leading: CGFloat, top: CGFloat,
                trailing: CGFloat, bottom: CGFloat) {
        physical = CGRect(origin: .zero, size: fullSize)
        safe = CGRect(x: leading, y: top,
                      width: max(0, fullSize.width - leading - trailing),
                      height: max(0, fullSize.height - top - bottom))
        let height = min(fullSize.width * 9 / 16, fullSize.height)
        let width = height * 16 / 9
        playable = CGRect(x: (fullSize.width - width) / 2,
                          y: (fullSize.height - height) / 2,
                          width: width, height: height)
    }

    /// The safe area's inset from the physical screen edge.
    public func safeAreaInset(_ edge: ScreenEdge) -> CGFloat {
        switch edge {
        case .leading:  return safe.minX - physical.minX
        case .trailing: return physical.maxX - safe.maxX
        case .top:      return safe.minY - physical.minY
        case .bottom:   return physical.maxY - safe.maxY
        }
    }

    /// How far from the physical screen edge chrome must sit: the safe-area
    /// inset where that already exceeds `margin`, otherwise `margin`.
    ///
    /// The two are alternatives, never addends. A deep inset — an iPhone's
    /// notch in landscape — already holds content clear of the edge, so
    /// adding a margin on top of it would indent the element twice. A zero
    /// inset provides no clearance at all, so the margin has to supply it.
    public func chromeInset(_ edge: ScreenEdge, margin: CGFloat) -> CGFloat {
        max(safeAreaInset(edge), margin)
    }
}
