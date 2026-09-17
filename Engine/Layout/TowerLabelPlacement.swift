import CoreGraphics

/// Screen-point geometry. Text is measured at each proposed width before a
/// side is chosen; neither the font nor the finished label is scaled to fit.
public enum TowerLabelPlacement {
    public enum Side: CaseIterable { case top, right, left, bottom }

    public struct Placement {
        public let side: Side
        public let frame: CGRect
        public let contentHeight: CGFloat
        public var needsScrolling: Bool { contentHeight > frame.height }
    }

    public static func resolve(button: CGRect, safeBounds: CGRect,
                               avoiding obstacles: [CGRect] = [],
                               preferredWidth: CGFloat = 320,
                               gap: CGFloat = 8,
                               measure: (CGFloat) -> CGFloat) -> Placement? {
        let safe = safeBounds.insetBy(dx: 6, dy: 6)
        guard safe.width > 0, safe.height > 0 else { return nil }
        let blockers = obstacles.map { $0.insetBy(dx: -4, dy: -4) }
        func region(_ side: Side) -> CGRect {
            switch side {
            case .top:
                return CGRect(x: safe.minX, y: safe.minY, width: safe.width,
                              height: max(0, button.minY - gap - safe.minY))
            case .right:
                let x = max(safe.minX, button.maxX + gap)
                return CGRect(x: x, y: safe.minY, width: max(0, safe.maxX - x), height: safe.height)
            case .left:
                return CGRect(x: safe.minX, y: safe.minY,
                              width: max(0, button.minX - gap - safe.minX), height: safe.height)
            case .bottom:
                let y = max(safe.minY, button.maxY + gap)
                return CGRect(x: safe.minX, y: y, width: safe.width, height: max(0, safe.maxY - y))
            }
        }
        func frames(side: Side, area: CGRect, width: CGFloat, height: CGFloat) -> [CGRect] {
            guard width <= area.width, height <= area.height else { return [] }
            let vertical = side == .top || side == .bottom
            let low = vertical ? area.minX : area.minY
            let high = vertical ? area.maxX - width : area.maxY - height
            let ideal = vertical ? button.midX - width / 2 : button.midY - height / 2
            let offsets = [ideal, low, high] + blockers.flatMap {
                vertical ? [$0.minX - width, $0.maxX] : [$0.minY - height, $0.maxY]
            }
            return offsets.map { min(max($0, low), high) }
                .sorted { abs($0 - ideal) < abs($1 - ideal) }
                .map { offset in
                    switch side {
                    case .top: return CGRect(x: offset, y: area.maxY - height, width: width, height: height)
                    case .right: return CGRect(x: area.minX, y: offset, width: width, height: height)
                    case .left: return CGRect(x: area.maxX - width, y: offset, width: width, height: height)
                    case .bottom: return CGRect(x: offset, y: area.minY, width: width, height: height)
                    }
                }
        }
        var scrollCandidates: [Placement] = []
        for side in Side.allCases {
            let area = region(side)
            guard area.width >= 160, area.height >= 60 else { continue }
            // Try the comfortable reading width first, then use additional
            // space or a narrower column if that lets the entire copy fit.
            let widths = [min(preferredWidth, area.width), min(440, area.width), min(240, area.width)]
            for width in widths {
                let height = ceil(measure(width))
                if let frame = frames(side: side, area: area, width: width, height: height)
                    .first(where: { rect in !blockers.contains { $0.intersects(rect) } }) {
                    return Placement(side: side, frame: frame, contentHeight: height)
                }
                let heights = [min(height, area.height)] + blockers.flatMap {
                    [min(height, $0.minY - area.minY), min(height, area.maxY - $0.maxY)]
                }
                for visibleHeight in heights where visibleHeight >= 60 && visibleHeight < height {
                    if let frame = frames(side: side, area: area, width: width, height: visibleHeight)
                        .first(where: { rect in !blockers.contains { $0.intersects(rect) } }) {
                        scrollCandidates.append(Placement(side: side, frame: frame, contentHeight: height))
                    }
                }
            }
        }
        // Extremely large accessibility text or unusually long authored copy:
        // keep the type readable and expose the rest by scrolling. Normal
        // full-content placements on all four sides always take precedence.
        return scrollCandidates.max {
            $0.frame.height / $0.contentHeight < $1.frame.height / $1.contentHeight
        }
    }
}
