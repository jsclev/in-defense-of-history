import Foundation
import CoreGraphics

public struct VirtualCanvas: Equatable, Sendable {
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
    public let lowerLeftOcclusionArea: CGRect
    public let lowerRightOcclusionArea: CGRect

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
            CGSize(width: playAreaRect.width * f.width,
                   height: playAreaRect.height * f.height)
        }
        let ul = cornerSize(statsViewSizeFraction)
        let ur = cornerSize(masterControlsSizeFraction)
        let ll = cornerSize(heroBarSizeFraction)
        let lr = cornerSize(miscViewSizeFraction)
        upperLeftOcclusionArea = CGRect(x: playAreaRect.minX,
                                        y: playAreaRect.maxY - ul.height,
                                        width: ul.width, height: ul.height)
        upperRightOcclusionArea = CGRect(x: playAreaRect.maxX - ur.width,
                                         y: playAreaRect.maxY - ur.height,
                                         width: ur.width, height: ur.height)
        lowerLeftOcclusionArea = CGRect(x: playAreaRect.minX,
                                        y: playAreaRect.minY,
                                        width: ll.width, height: ll.height)
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

    /// Where a slot's CENTRE may sit. Test placements against this.
    public var towerSlotValidCentres: CGPath { slotValidShape(measuringFootprintEdge: false) }

    /// Where the outer edge of a slot's pad may reach. Draw this.
    public var towerSlotValidFootprint: CGPath { slotValidShape(measuringFootprintEdge: true) }

    private func slotValidShape(measuringFootprintEdge: Bool) -> CGPath {
        let menuHalfWidth = towerMenuTotalSize.width / 2
        let menuHalfHeight = towerMenuTotalSize.height / 2
        let slotHalfWidth = towerSlotSize.width / 2
        let slotHalfHeight = towerSlotSize.height / 2
        let insetWidth = measuringFootprintEdge ? menuHalfWidth - slotHalfWidth : menuHalfWidth
        let insetHeight = measuringFootprintEdge ? menuHalfHeight - slotHalfHeight : menuHalfHeight
        let upperLeftStandoffWidth = measuringFootprintEdge ? 0 : slotHalfWidth
        let upperLeftStandoffHeight = measuringFootprintEdge ? 0 : slotHalfHeight

        let valid = CGMutablePath()
        valid.addRect(playAreaRect.insetBy(dx: insetWidth, dy: insetHeight))
        let blocked = CGMutablePath()
        for corner in [lowerLeftOcclusionArea, lowerRightOcclusionArea, upperRightOcclusionArea] {
            blocked.addRect(corner.insetBy(dx: -insetWidth, dy: -insetHeight))
        }
        blocked.addRect(upperLeftOcclusionArea.insetBy(dx: -upperLeftStandoffWidth,
                                                       dy: -upperLeftStandoffHeight))
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

    public var playAreaShape: CGPath {
        let play = playAreaRect
        // Cuts extend past the boundary so subtraction removes the shared edge cleanly.
        let pad = 6.0
        let shape = CGMutablePath()
        shape.addRect(play)
        let cuts = CGMutablePath()
        for corner in cornerOcclusionAreas {
            var cut = corner
            if abs(corner.minX - play.minX) < 0.5 { cut.origin.x -= pad; cut.size.width += pad }
            if abs(corner.maxX - play.maxX) < 0.5 { cut.size.width += pad }
            if abs(corner.minY - play.minY) < 0.5 { cut.origin.y -= pad; cut.size.height += pad }
            if abs(corner.maxY - play.maxY) < 0.5 { cut.size.height += pad }
            cuts.addRect(cut)
        }
        return shape.subtracting(cuts, using: .winding)
    }
}
