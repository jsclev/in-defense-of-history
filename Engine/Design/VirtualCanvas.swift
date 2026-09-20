import Foundation
import CoreGraphics

public struct VirtualCanvas: Codable, Equatable, Sendable {
    public let size: CGSize
    public let pathWidth: Double

    public let playAreaRect: CGRect
    public let towerSlotSize: CGSize
    public let towerMenuTotalSize: CGSize
    public let statsViewSizeFraction: CGSize
    public let masterControlsSizeFraction: CGSize
    public let heroBarSizeFraction: CGSize
    public let miscViewSizeFraction: CGSize
    public let upperLeftOcclusionArea: CGRect
    public let upperRightOcclusionArea: CGRect
    public let lowerRightOcclusionArea: CGRect

    /// HUD reservations use the original corner dimensions, independently of
    /// the extra lower-left clearance required by the road.
    public var hudPlayArea: HudPlayArea {
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        let referencePlay = playAreaRect.applying(flip)
        let bounds = HudPlayArea.layoutBounds(physical: CGRect(origin: .zero, size: size),
                                              safe: referencePlay, play: referencePlay)
        return hudPlayArea(in: bounds.applying(flip))
    }

    public func hudPlayArea(in bounds: CGRect) -> HudPlayArea {
        func size(_ fraction: CGSize) -> CGSize {
            CGSize(width: playAreaRect.width * fraction.width,
                   height: playAreaRect.height * fraction.height * 0.9)
        }
        return HudPlayArea(bounds: bounds, upperLeft: size(statsViewSizeFraction),
                           upperRight: size(masterControlsSizeFraction),
                           lowerLeft: size(heroBarSizeFraction), lowerRight: size(miscViewSizeFraction))
    }

    /// The existing space used to size the hero buttons. Extra road clearance
    /// above this area must not enlarge the HUD artwork.
    public var heroBarLayoutArea: CGRect {
        CGRect(x: playAreaRect.minX, y: playAreaRect.minY,
               width: playAreaRect.width * heroBarSizeFraction.width,
               height: playAreaRect.height * heroBarSizeFraction.height * 0.9)
    }

    /// Reserve 30% more height above the hero bar. Derive this on access so
    /// older saved editor canvases cannot restore the obsolete cutout height.
    public var lowerLeftOcclusionArea: CGRect {
        let area = heroBarLayoutArea
        return CGRect(x: area.minX, y: area.minY,
                      width: area.width, height: area.height * 1.3)
    }

    public init(size: CGSize,
                playAreaRect: CGRect,
                pathWidth: Double,
                towerSlotSize: CGSize,
                towerMenuTotalSize: CGSize,
                statsViewSizeFraction: CGSize,
                masterControlsSizeFraction: CGSize,
                heroBarSizeFraction: CGSize,
                miscViewSizeFraction: CGSize) {
        self.size = size
        self.playAreaRect = playAreaRect
        self.pathWidth = pathWidth
        self.towerSlotSize = towerSlotSize
        self.towerMenuTotalSize = towerMenuTotalSize
        self.statsViewSizeFraction = statsViewSizeFraction
        self.masterControlsSizeFraction = masterControlsSizeFraction
        self.heroBarSizeFraction = heroBarSizeFraction
        self.miscViewSizeFraction = miscViewSizeFraction

        let cornerSize = { (f: CGSize) in
            // Reserve 90% of each HUD region's height for the corner cutout.
            CGSize(width: playAreaRect.width * f.width,
                   height: playAreaRect.height * f.height * 0.9)
        }
        let ul = cornerSize(statsViewSizeFraction)
        let ur = cornerSize(masterControlsSizeFraction)
        let lr = cornerSize(miscViewSizeFraction)
        upperLeftOcclusionArea = CGRect(x: playAreaRect.minX,
                                        y: playAreaRect.maxY - ul.height,
                                        width: ul.width, height: ul.height)
        upperRightOcclusionArea = CGRect(x: playAreaRect.maxX - ur.width,
                                         y: playAreaRect.maxY - ur.height,
                                         width: ur.width, height: ur.height)
        lowerRightOcclusionArea = CGRect(x: playAreaRect.maxX - lr.width,
                                         y: playAreaRect.minY,
                                         width: lr.width, height: lr.height)
    }
    
    public func slotFootprintContains(_ point: CGPoint, slot: CGPoint) -> Bool {
        let a = towerSlotSize.width / 2, b = towerSlotSize.height / 2
        guard a > 0, b > 0 else { return false }
        let dx = (point.x - slot.x) / a, dy = (point.y - slot.y) / b
        return dx * dx + dy * dy <= 1
    }

    public func slotFootprintsOverlap(_ p: CGPoint, _ q: CGPoint) -> Bool {
        let a = towerSlotSize.width, b = towerSlotSize.height
        guard a > 0, b > 0 else { return false }
        let dx = (p.x - q.x) / a, dy = (p.y - q.y) / b
        return dx * dx + dy * dy < 1
    }

    public var cornerOcclusionAreas: [CGRect] {
        [lowerLeftOcclusionArea, lowerRightOcclusionArea,
         upperLeftOcclusionArea, upperRightOcclusionArea]
    }

    /// Largest verified landscape home-indicator / full-screen width ratio:
    /// iPad mini (6th generation), 315 pt / 1133 pt. See the measurement report
    /// in Tools/reports/bottom-center-occlusion-2026-09-09.
    public static let homeIndicatorScreenWidthFraction: CGFloat = 315.0 / 1133.0

    /// Authored geometry uses the full virtual canvas as its screen reference.
    /// Computed so existing saved canvases acquire the cutout without migration.
    public var bottomCenterOcclusionArea: CGRect {
        bottomCenterOcclusionArea(forScreenWidth: size.width)
    }

    /// `screenWidth` must be expressed in canonical map units. RuntimeCanvas
    /// converts the physical screen width using the live map scale.
    public func bottomCenterOcclusionArea(forScreenWidth screenWidth: CGFloat) -> CGRect {
        let width = min(playAreaRect.width, max(0, screenWidth) * Self.homeIndicatorScreenWidthFraction)
        return CGRect(x: playAreaRect.midX - width / 2,
                      y: playAreaRect.minY,
                      width: width,
                      height: heroBarLayoutArea.height * 0.2)
    }

    public var occlusionAreas: [CGRect] { occlusionAreas(forScreenWidth: size.width) }

    public func occlusionAreas(forScreenWidth screenWidth: CGFloat) -> [CGRect] {
        cornerOcclusionAreas + [bottomCenterOcclusionArea(forScreenWidth: screenWidth)]
    }

    /// Where a slot's CENTRE may sit. Test placements against this.
    public var towerSlotValidCentres: CGPath {
        towerSlotValidCentres(forScreenWidth: size.width, hudArea: hudPlayArea)
    }

    public func towerSlotValidCentres(forScreenWidth screenWidth: CGFloat, hudArea: HudPlayArea) -> CGPath {
        slotValidShape(measuringFootprintEdge: false, screenWidth: screenWidth, hudArea: hudArea)
    }

    /// Where the outer edge of a slot's pad may reach. Draw this.
    public var towerSlotValidFootprint: CGPath { towerSlotValidFootprint(forScreenWidth: size.width) }

    public func towerSlotValidFootprint(forScreenWidth screenWidth: CGFloat) -> CGPath {
        towerSlotValidFootprint(forScreenWidth: screenWidth, hudArea: hudPlayArea)
    }

    public func towerSlotValidFootprint(forScreenWidth screenWidth: CGFloat, hudArea: HudPlayArea) -> CGPath {
        slotValidShape(measuringFootprintEdge: true, screenWidth: screenWidth, hudArea: hudArea)
    }

    private func slotValidShape(measuringFootprintEdge: Bool, screenWidth: CGFloat, hudArea: HudPlayArea) -> CGPath {
        let interactionExtent = TowerMenuLayout(virtualCanvas: self).interactionExtent
        let menuHalfWidth = max(towerMenuTotalSize.width / 2, interactionExtent)
        let menuHalfHeight = max(towerMenuTotalSize.height / 2, interactionExtent)
        let slotHalfWidth = towerSlotSize.width / 2
        let slotHalfHeight = towerSlotSize.height / 2
        let insetWidth = measuringFootprintEdge ? menuHalfWidth - slotHalfWidth : menuHalfWidth
        let insetHeight = measuringFootprintEdge ? menuHalfHeight - slotHalfHeight : menuHalfHeight

        let valid = CGMutablePath()
        valid.addRect(playAreaRect.insetBy(dx: insetWidth, dy: insetHeight))
        let blocked = CGMutablePath()
        for corner in hudArea.occlusionAreas where !corner.isEmpty {
            blocked.addRect(corner.insetBy(dx: -insetWidth, dy: -insetHeight))
        }
        let bottomCenter = bottomCenterOcclusionArea(forScreenWidth: screenWidth)
        if !bottomCenter.isEmpty {
            blocked.addRect(bottomCenter.insetBy(dx: -insetWidth, dy: -insetHeight))
        }
        return valid.subtracting(blocked, using: .winding)
    }

    public func flipY(_ y: Double) -> Double { size.height - y }

    public func playableRect(in fullSize: CGSize) -> CGRect {
        guard playAreaRect.width > 0, playAreaRect.height > 0 else {
            return CGRect(origin: .zero, size: fullSize)
        }
        let aspect = playAreaRect.width / playAreaRect.height
        let height = min(fullSize.width / aspect, fullSize.height)
        let width = height * aspect
        return CGRect(x: (fullSize.width - width) / 2,
                      y: (fullSize.height - height) / 2,
                      width: width, height: height)
    }

    public var playAreaShape: CGPath { playAreaShape(forScreenWidth: size.width) }

    /// Lower the exposed path edge without changing the 16:9 reference bounds.
    public static let pathAreaTopInsetFraction: CGFloat = 0.09

    /// Minimum top clearance for taps, which also stay inside the path area.
    public static let tapAreaTopInsetFraction: CGFloat = 0.05

    public var pathAreaTopExclusionArea: CGRect {
        topExclusionArea(insetFraction: Self.pathAreaTopInsetFraction)
    }

    public var tapAreaTopExclusionArea: CGRect {
        topExclusionArea(insetFraction: Self.tapAreaTopInsetFraction)
    }

    /// Only the top segment between the upper corner occlusions moves inward.
    /// Canonical map coordinates have +Y up, so downward means decreasing Y.
    private func topExclusionArea(insetFraction: CGFloat) -> CGRect {
        let play = playAreaRect
        let left = upperLeftOcclusionArea.isEmpty ? play.minX
            : min(play.maxX, max(play.minX, upperLeftOcclusionArea.maxX))
        let right = upperRightOcclusionArea.isEmpty ? play.maxX
            : max(play.minX, min(play.maxX, upperRightOcclusionArea.minX))
        let height = play.height * insetFraction
        return CGRect(x: left, y: play.maxY - height,
                      width: max(0, right - left), height: height)
    }

    /// Placement region for tappable map elements, inside the play polygon.
    public var tapAreaShape: CGPath { tapAreaShape(forScreenWidth: size.width) }

    public func tapAreaShape(forScreenWidth screenWidth: CGFloat) -> CGPath {
        let play = playAreaShape(forScreenWidth: screenWidth)
        let exclusion = tapAreaTopExclusionArea
        guard !exclusion.isEmpty else { return play }
        // Extend past shared outer edges, as for the play-area occlusions, so
        // path subtraction cannot leave a stray segment on the old boundary.
        let pad: CGFloat = 6
        var cut = exclusion
        cut.size.height += pad
        if exclusion.minX == playAreaRect.minX { cut.origin.x -= pad; cut.size.width += pad }
        if exclusion.maxX == playAreaRect.maxX { cut.size.width += pad }
        return play.subtracting(CGPath(rect: cut, transform: nil), using: .winding)
    }

    /// Paths reach both horizontal extents of playAreaRect between its corner
    /// cutouts. Tower-menu clearance belongs only to the tower-slot shapes.
    public func playAreaShape(forScreenWidth screenWidth: CGFloat) -> CGPath {
        let play = playAreaRect
        // Cuts extend past the boundary so subtraction removes the shared edge cleanly.
        let pad = 6.0
        let shape = CGMutablePath()
        shape.addRect(play)
        let cuts = CGMutablePath()
        for occlusion in occlusionAreas(forScreenWidth: screenWidth) + [pathAreaTopExclusionArea] where !occlusion.isEmpty {
            var cut = occlusion
            if abs(occlusion.minX - play.minX) < 0.5 { cut.origin.x -= pad; cut.size.width += pad }
            if abs(occlusion.maxX - play.maxX) < 0.5 { cut.size.width += pad }
            if abs(occlusion.minY - play.minY) < 0.5 { cut.origin.y -= pad; cut.size.height += pad }
            if abs(occlusion.maxY - play.maxY) < 0.5 { cut.size.height += pad }
            cuts.addRect(cut)
        }
        return shape.subtracting(cuts, using: .winding)
    }
}
