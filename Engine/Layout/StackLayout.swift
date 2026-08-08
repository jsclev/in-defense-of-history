import CoreGraphics

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

    public func placed(at origin: CGPoint) -> [CGRect] {
        frames.map { $0.offsetBy(dx: origin.x, dy: origin.y) }
    }
}
