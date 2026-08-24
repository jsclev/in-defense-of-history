import Foundation
import CoreGraphics

public struct VirtualCanvas: Equatable {
    public let size: CGSize
    public let pathWidth: Double

    public let playAreaRect: CGRect
    public let towerSlotSize: CGSize
    public let towerMenuTotalSize: CGSize
    public let upperLeftOcclusionCornerFraction: CGSize
    public let upperRightOcclusionCornerFraction: CGSize
    public let lowerLeftOcclusionCornerFraction: CGSize
    public let lowerRightOcclusionCornerFraction: CGSize
    
    public init(size: CGSize,
                playAreaRect: CGRect,
                pathWidth: Double,
                towerSlotSize: CGSize,
                towerMenuTotalSize: CGSize,
                upperLeftOcclusionCornerFraction: CGSize,
                upperRightOcclusionCornerFraction: CGSize,
                lowerLeftOcclusionCornerFraction: CGSize,
                lowerRightOcclusionCornerFraction: CGSize) {
        self.size = size
        self.playAreaRect = playAreaRect
        self.pathWidth = pathWidth
        self.towerSlotSize = towerSlotSize
        self.towerMenuTotalSize = towerMenuTotalSize
        self.upperLeftOcclusionCornerFraction = upperLeftOcclusionCornerFraction
        self.upperRightOcclusionCornerFraction = upperRightOcclusionCornerFraction
        self.lowerLeftOcclusionCornerFraction = lowerLeftOcclusionCornerFraction
        self.lowerRightOcclusionCornerFraction = lowerRightOcclusionCornerFraction
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
        let area = playAreaRect
        func size(_ f: CGSize) -> CGSize { CGSize(width: area.width * f.width, height: area.height * f.height) }
        let ul = size(upperLeftOcclusionCornerFraction)
        let ur = size(upperRightOcclusionCornerFraction)
        let ll = size(lowerLeftOcclusionCornerFraction)
        let lr = size(lowerRightOcclusionCornerFraction)
        return [
            CGRect(x: area.minX, y: area.minY, width: ll.width, height: ll.height),
            CGRect(x: area.maxX - lr.width, y: area.minY, width: lr.width, height: lr.height),
            CGRect(x: area.minX, y: area.maxY - ul.height, width: ul.width, height: ul.height),
            CGRect(x: area.maxX - ur.width, y: area.maxY - ur.height, width: ur.width, height: ur.height),
        ]
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
