import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

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

    public func safeAreaInset(_ edge: ScreenEdge) -> CGFloat {
        switch edge {
        case .leading:  return safe.minX - physical.minX
        case .trailing: return physical.maxX - safe.maxX
        case .top:      return safe.minY - physical.minY
        case .bottom:   return physical.maxY - safe.maxY
        }
    }

    public func chromeInset(_ edge: ScreenEdge, margin: CGFloat) -> CGFloat {
        max(safeAreaInset(edge), margin)
    }
}
