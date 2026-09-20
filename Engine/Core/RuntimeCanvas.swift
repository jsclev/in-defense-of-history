import CoreGraphics

public enum ScreenEdge {
    case leading, trailing, top, bottom
}

public struct RuntimeCanvas {
    public let virtualCanvas: VirtualCanvas
    public let hudPlayArea: HudPlayArea
    public var runtimeHUDPlayArea: CGPath { hudPlayArea.shape }
    public let physicalRect: CGRect
    public let safeInsetsRect: CGRect
    public let playAreaRect: CGRect
    public let runtimePlayArea: CGPath
    /// Movement gestures use the path area with actual HUD controls excluded.
    public var runtimeMapInputArea: CGPath { hudPlayArea.excludingControls(from: runtimePlayArea) }
    /// Screen-coordinate placement region for tappable map elements.
    public let runtimeTapArea: CGPath
    public let occlusionAreas: [CGRect]
    public let bottomCenterOcclusionArea: CGRect
    public let towerSlotValidArea: CGPath
    public let towerSlotValidCentres: CGPath
    public let scaleFactor: CGFloat
    public let maxY: CGFloat
    public let marginScaleFactor = HudPlayArea.marginFraction
    public let hudTopMargin: CGFloat
    public let hudHorizontalMargin: CGFloat
    public let hudBottomMargin: CGFloat
    public var heroBarSize: CGSize { hudPlayArea.lowerLeftOcclusionArea.size }
    public var statsViewSize: CGSize { hudPlayArea.upperLeftOcclusionArea.size }
    public var miscViewSize: CGSize { hudPlayArea.lowerRightOcclusionArea.size }
    public var masterControlsSize: CGSize { hudPlayArea.upperRightOcclusionArea.size }

    /// Database ranges are radii in canonical map units, just like combat
    /// positions. Resolve them with the live play-area fit, never a device's
    /// pixel density, image dimensions, or a cached screen-size multiplier.
    public func rangeRadius(forMapRadius radius: CGFloat) -> CGFloat {
        max(0, radius) * scaleFactor
    }

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
        occlusionAreas = virtualCanvas.occlusionAreas(forScreenWidth: screenWidthInMapUnits)
            .map { $0.applying(transform) }
        bottomCenterOcclusionArea = virtualCanvas.bottomCenterOcclusionArea(forScreenWidth: screenWidthInMapUnits)
            .applying(transform)

        
        var safeMargin = playAreaRect.height * marginScaleFactor
        
        if physicalRect.height - safeInsetsRect.height >= safeMargin {
            safeMargin = 0.0
        }
        
        maxY = safeInsetsRect.maxY - safeMargin
        
        let hudBounds = HudPlayArea.layoutBounds(physical: physicalRect, safe: safeInsetsRect, play: playAreaRect)
        let canonicalHUDBounds = hudBounds.applying(transform.inverted())
        let canonicalHUD = virtualCanvas.hudPlayArea(in: canonicalHUDBounds)
        hudPlayArea = canonicalHUD.applying(transform)
        runtimeTapArea = hudPlayArea.excludingControls(from: tapShape.copy(using: &transform) ?? tapShape)
        let validShape = virtualCanvas.towerSlotValidFootprint(forScreenWidth: screenWidthInMapUnits, hudArea: canonicalHUD)
        towerSlotValidArea = validShape.copy(using: &transform) ?? validShape
        let validCentres = virtualCanvas.towerSlotValidCentres(forScreenWidth: screenWidthInMapUnits, hudArea: canonicalHUD)
        towerSlotValidCentres = validCentres.copy(using: &transform) ?? validCentres
        hudHorizontalMargin = hudBounds.minX
        hudTopMargin = hudBounds.minY
        hudBottomMargin = physicalRect.maxY - hudBounds.maxY
    }
}
