import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

public struct RuntimeCanvas {
    public let virtualCanvas: VirtualCanvas
    public let hudRect: CGRect
    public let physicalRect: CGRect
    public let safeInsetsRect: CGRect
    public let playAreaRect: CGRect
    public let runtimePlayArea: CGPath
    /// Screen-coordinate placement region for tappable map elements.
    public let runtimeTapArea: CGPath
    public let occlusionAreas: [CGRect]
    public let bottomCenterOcclusionArea: CGRect
    public let towerSlotValidArea: CGPath
    public let scaleFactor: CGFloat
    public let maxY: CGFloat
    public let marginScaleFactor = 0.02
    public let hudTopMargin: CGFloat
    public let hudHorizontalMargin: CGFloat
    public let hudBottomMargin: CGFloat
    public let heroBarSize: CGSize
    public let statsViewSize: CGSize
    public let miscViewSize: CGSize
    public let masterControlsSize: CGSize

    /// Database ranges are radii in canonical map units, just like combat
    /// positions. Resolve them with the live play-area fit, never a device's
    /// pixel density, image dimensions, or a cached screen-size multiplier.
    public func rangeRadius(forMapRadius radius: CGFloat) -> CGFloat {
        max(0, radius) * scaleFactor
    }
//    private let hudMarginFactor = 0.04
//    public let hudLowerLeftRect: CGRect

    public init(virtualCanvas: VirtualCanvas,
                physicalRect: CGRect,
                safeInsetsRect: CGRect) {
        self.virtualCanvas = virtualCanvas
        self.physicalRect = physicalRect
        self.safeInsetsRect = safeInsetsRect

        let virtualPlayArea = virtualCanvas.playAreaRect
        scaleFactor = min(safeInsetsRect.width / virtualPlayArea.width,
                          safeInsetsRect.height / virtualPlayArea.height)

        let width = virtualPlayArea.width * scaleFactor
        let height = virtualPlayArea.height * scaleFactor
        playAreaRect = CGRect(x: safeInsetsRect.midX - width / 2,
                              y: safeInsetsRect.midY - height / 2,
                              width: width,
                              height: height)
        
        var transform = CGAffineTransform(
            a: scaleFactor,
            b: 0,
            c: 0,
            d: -scaleFactor,
            tx: playAreaRect.minX - virtualPlayArea.minX * scaleFactor,
            ty: playAreaRect.minY + virtualPlayArea.maxY * scaleFactor)
        
        let screenWidthInMapUnits = scaleFactor > 0 ? physicalRect.width / scaleFactor : 0
        let playShape = virtualCanvas.playAreaShape(forScreenWidth: screenWidthInMapUnits)
        runtimePlayArea = playShape.copy(using: &transform) ?? playShape
        let tapShape = virtualCanvas.tapAreaShape(forScreenWidth: screenWidthInMapUnits)
        runtimeTapArea = tapShape.copy(using: &transform) ?? tapShape
        occlusionAreas = virtualCanvas.occlusionAreas(forScreenWidth: screenWidthInMapUnits)
            .map { $0.applying(transform) }
        bottomCenterOcclusionArea = virtualCanvas.bottomCenterOcclusionArea(forScreenWidth: screenWidthInMapUnits)
            .applying(transform)

        let validShape = virtualCanvas.towerSlotValidFootprint(forScreenWidth: screenWidthInMapUnits)
        towerSlotValidArea = validShape.copy(using: &transform) ?? validShape
        
        var safeMargin = playAreaRect.height * marginScaleFactor
        
        if physicalRect.height - safeInsetsRect.height >= safeMargin {
            safeMargin = 0.0
        }
        
        maxY = safeInsetsRect.maxY - safeMargin
        
        let horizontalMargin = playAreaRect.width * marginScaleFactor

        var hudMinX = min(safeInsetsRect.minX, playAreaRect.minX)
        if hudMinX < horizontalMargin {
            hudMinX = horizontalMargin
        }
        
        var hudMaxX = max(safeInsetsRect.maxX, playAreaRect.maxX)
        if physicalRect.maxX - safeInsetsRect.maxX < horizontalMargin {
            hudMaxX -= horizontalMargin
        }
        
        let verticalPhysicalMargin = physicalRect.height - safeInsetsRect.height
        var hudMaxY = playAreaRect.maxY
        
        if verticalPhysicalMargin > playAreaRect.height * marginScaleFactor {
            hudMaxY = safeInsetsRect.maxY
        }
        let verticalMargin = playAreaRect.height * marginScaleFactor
//        let horizontalMargin = playAreaRect.width * marginScaleFactor
//        let verticalMargin = playAreaRect.height * marginScaleFactor
        
        let hudMinY = min(safeInsetsRect.minY, playAreaRect.minY) + verticalMargin
        
        hudRect = CGRect(
            x: hudMinX,
            y: hudMinY,
            width: hudMaxX - hudMinX,
            height: hudMaxY - hudMinY
        )
        
        hudHorizontalMargin = hudRect.minX
        hudTopMargin = hudRect.minY
        hudBottomMargin = physicalRect.maxY - hudRect.maxY
        
        heroBarSize = CGSize(
            width: virtualCanvas.heroBarSizeFraction.width * playAreaRect.width,
            height: virtualCanvas.heroBarSizeFraction.height * playAreaRect.height)
        statsViewSize = CGSize(
            width: virtualCanvas.statsViewSizeFraction.width * playAreaRect.width,
            height: virtualCanvas.statsViewSizeFraction.height * playAreaRect.height)
        miscViewSize = CGSize(
            width: virtualCanvas.miscViewSizeFraction.width * playAreaRect.width,
            height: virtualCanvas.miscViewSizeFraction.height * playAreaRect.height)
        masterControlsSize = CGSize(
            width: virtualCanvas.masterControlsSizeFraction.width * playAreaRect.width,
            height: virtualCanvas.masterControlsSizeFraction.height * playAreaRect.height)
    }
    
//    public var lowerLeftHudWidth: CGFloat {
//        let extraWidth = (safeInsetsRect.width - playAreaRect.width) / 2.0
////        let occlusionWidth = virtualCanvas.heroBarSizeFraction.width * playAreaRect.width
//        
//        return virtualCanvas.heroBarSizeFraction.width * playAreaRect.width + extraWidth
//    }
}
