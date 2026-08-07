import CoreGraphics

/// Pure row/column composition: item sizes in, item frames and an overall
/// size out. This is the only place HUD code computes "things next to each
/// other", so a spacing or alignment fix lands everywhere at once.
///
/// Frames are in the stack's own space, origin at the top-leading corner.
/// Rows align tops, columns align leading edges — HUD elements share edges,
/// they don't centre on each other.
public struct StackLayout: Equatable {
    public let frames: [CGRect]
    public let size: CGSize

    public static func row(_ itemSizes: [CGSize], spacing: CGFloat) -> StackLayout {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var height: CGFloat = 0
        for item in itemSizes {
            frames.append(CGRect(x: x, y: 0, width: item.width, height: item.height))
            x += item.width + spacing
            height = max(height, item.height)
        }
        return StackLayout(frames: frames,
                           size: CGSize(width: itemSizes.isEmpty ? 0 : x - spacing,
                                        height: height))
    }

    public static func column(_ itemSizes: [CGSize], spacing: CGFloat) -> StackLayout {
        var frames: [CGRect] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        for item in itemSizes {
            frames.append(CGRect(x: 0, y: y, width: item.width, height: item.height))
            y += item.height + spacing
            width = max(width, item.width)
        }
        return StackLayout(frames: frames,
                           size: CGSize(width: width,
                                        height: itemSizes.isEmpty ? 0 : y - spacing))
    }

    /// The same stack translated into a parent's coordinate space.
    public func placed(at origin: CGPoint) -> [CGRect] {
        frames.map { $0.offsetBy(dx: origin.x, dy: origin.y) }
    }
}
