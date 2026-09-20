import CoreGraphics

/// The space between four reserved HUD corners. The cutouts, rather than the
/// polygon's bounding rectangle, own the HUD controls and their touch targets.
public struct HudPlayArea {
    public static let marginFraction: CGFloat = 0.02
    public let bounds: CGRect
    public let upperLeftOcclusionArea: CGRect
    public let upperRightOcclusionArea: CGRect
    public let lowerLeftOcclusionArea: CGRect
    public let lowerRightOcclusionArea: CGRect

    /// Shared screen-coordinate envelope, used by the authored reference and
    /// live device projection before cutting out the four HUD reservations.
    public static func layoutBounds(physical: CGRect, safe: CGRect, play: CGRect) -> CGRect {
        let horizontalMargin = play.width * marginFraction
        let verticalMargin = play.height * marginFraction
        let left = max(min(safe.minX, play.minX), physical.minX + horizontalMargin)
        var right = max(safe.maxX, play.maxX)
        if physical.maxX - safe.maxX < horizontalMargin { right -= horizontalMargin }
        let top = min(safe.minY, play.minY) + verticalMargin
        let bottom = physical.height - safe.height > verticalMargin ? safe.maxY : play.maxY
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// Canonical map coordinates (+Y up).
    public init(bounds: CGRect, upperLeft: CGSize, upperRight: CGSize,
                lowerLeft: CGSize, lowerRight: CGSize) {
        self.bounds = bounds
        upperLeftOcclusionArea = CGRect(x: bounds.minX, y: bounds.maxY - upperLeft.height,
                                       width: upperLeft.width, height: upperLeft.height)
        upperRightOcclusionArea = CGRect(x: bounds.maxX - upperRight.width, y: bounds.maxY - upperRight.height,
                                        width: upperRight.width, height: upperRight.height)
        lowerLeftOcclusionArea = CGRect(origin: bounds.origin, size: lowerLeft)
        lowerRightOcclusionArea = CGRect(x: bounds.maxX - lowerRight.width, y: bounds.minY,
                                        width: lowerRight.width, height: lowerRight.height)
    }

    private init(bounds: CGRect, upperLeft: CGRect, upperRight: CGRect,
                 lowerLeft: CGRect, lowerRight: CGRect) {
        self.bounds = bounds
        upperLeftOcclusionArea = upperLeft
        upperRightOcclusionArea = upperRight
        lowerLeftOcclusionArea = lowerLeft
        lowerRightOcclusionArea = lowerRight
    }

    public var occlusionAreas: [CGRect] {
        [lowerLeftOcclusionArea, lowerRightOcclusionArea,
         upperLeftOcclusionArea, upperRightOcclusionArea]
    }

    public func excludingControls(from path: CGPath) -> CGPath {
        let reserved = CGMutablePath()
        for corner in occlusionAreas where !corner.isEmpty { reserved.addRect(corner) }
        return path.subtracting(reserved, using: .winding)
    }

    public func occlusion(at location: HudLocation) -> CGRect {
        switch location {
        case .northWest: return upperLeftOcclusionArea
        case .northEast: return upperRightOcclusionArea
        case .southWest: return lowerLeftOcclusionArea
        case .southEast: return lowerRightOcclusionArea
        default: preconditionFailure("HUD location \(location.rawValue) has no reserved corner")
        }
    }

    /// Fit without stretching, anchored to the outside edges in screen coordinates.
    public func fittedFrame(size: CGSize, at location: HudLocation) -> CGRect {
        let corner = occlusion(at: location)
        let scale = size.width > 0 && size.height > 0
            ? max(0, min(corner.width / size.width, corner.height / size.height)) : 0
        let width = size.width * scale, height = size.height * scale
        let right = location == .northEast || location == .southEast
        let bottom = location == .southWest || location == .southEast
        return CGRect(x: right ? corner.maxX - width : corner.minX,
                      y: bottom ? corner.maxY - height : corner.minY,
                      width: width, height: height)
    }

    public var shape: CGPath {
        let cuts = CGMutablePath()
        for corner in occlusionAreas where !corner.isEmpty {
            var cut = corner
            // Extend only the shared exterior edges; preserve the exact inner
            // boundary and remove coincident outline segments from subtraction.
            let pad: CGFloat = 6
            if corner.minX == bounds.minX { cut.origin.x -= pad; cut.size.width += pad }
            if corner.maxX == bounds.maxX { cut.size.width += pad }
            if corner.minY == bounds.minY { cut.origin.y -= pad; cut.size.height += pad }
            if corner.maxY == bounds.maxY { cut.size.height += pad }
            cuts.addRect(cut)
        }
        return CGPath(rect: bounds, transform: nil).subtracting(cuts, using: .winding)
    }

    public func applying(_ transform: CGAffineTransform) -> HudPlayArea {
        HudPlayArea(bounds: bounds.applying(transform),
                    upperLeft: upperLeftOcclusionArea.applying(transform),
                    upperRight: upperRightOcclusionArea.applying(transform),
                    lowerLeft: lowerLeftOcclusionArea.applying(transform),
                    lowerRight: lowerRightOcclusionArea.applying(transform))
    }
}

/// Fits square buttons, including their gaps, entirely inside a HUD cutout.
public struct HudButtonRowLayout: Equatable {
    public let buttonSize: CGFloat
    public let buttonSpacing: CGFloat
    public let frame: CGRect

    public init(area: HudPlayArea, location: HudLocation, count: Int) {
        precondition(count > 0)
        let corner = area.occlusion(at: location)
        let sections = CGFloat(count) + CGFloat(count - 1) * 0.1
        buttonSize = max(0, min(corner.width / sections, corner.height))
        buttonSpacing = buttonSize * 0.1
        let width = sections * buttonSize
        let right = location == .northEast || location == .southEast
        let bottom = location == .southWest || location == .southEast
        frame = CGRect(x: right ? corner.maxX - width : corner.minX,
                       y: bottom ? corner.maxY - buttonSize : corner.minY,
                       width: width, height: buttonSize)
    }
}
