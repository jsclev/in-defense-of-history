import Foundation
import CoreGraphics

public struct CanvasSpec {
    public let size: CGSize
    public let playAreaRect: CGRect
    public let playArea: CGPath
    public let pathWidth: Double
    public let towerSlotSize: CGSize
    
//    public let upperLeftCutoutFraction: CGSize
//    public let upperRightCutoutFraction: CGSize
//    public let lowerRightCutoutFraction: CGSize
//    public let lowerLeftCutoutFraction: CGSize
    
//    public let cornerCutoutAreas: [CGRect]
    
    public init(size: CGSize,
                playAreaRect: CGRect,
                pathWidth: Double,
                towerSlotSize: CGSize,
                upperLeftCutoutFraction: CGSize,
                upperRightCutoutFraction: CGSize,
                lowerRightCutoutFraction: CGSize,
                lowerLeftCutoutFraction: CGSize) {
        self.size = size
        self.playAreaRect = playAreaRect
        self.pathWidth = pathWidth
        self.towerSlotSize = towerSlotSize
        
        let upperLeftCutout = CGRect(x: playAreaRect.minX,
                                     y: playAreaRect.minY,
                                     width: playAreaRect.width * upperLeftCutoutFraction.width,
                                     height: playAreaRect.height * upperLeftCutoutFraction.height)
        let upperRightCutout = CGRect(x: playAreaRect.maxX - (playAreaRect.width * upperRightCutoutFraction.width),
                                      y: playAreaRect.minY,
                                      width: playAreaRect.width * upperRightCutoutFraction.width,
                                      height: playAreaRect.height * upperRightCutoutFraction.height)
        let lowerRightCutout = CGRect(x: playAreaRect.maxX - (playAreaRect.width * lowerRightCutoutFraction.width),
                                      y: playAreaRect.maxY - (playAreaRect.height * lowerRightCutoutFraction.height),
                                      width: playAreaRect.width * lowerRightCutoutFraction.width,
                                      height: playAreaRect.height * lowerRightCutoutFraction.height)
        let lowerLeftCutout = CGRect(x: playAreaRect.minX,
                                     y: playAreaRect.maxY - (playAreaRect.height * lowerLeftCutoutFraction.height),
                                     width: playAreaRect.width * lowerLeftCutoutFraction.width,
                                     height: playAreaRect.height * lowerLeftCutoutFraction.height)
        
//        self.cornerCutoutAreas = [
//            upperLeftCutout,
//            upperRightCutout,
//            lowerRightCutout,
//            lowerLeftCutout,
//        ]
        
        let playAreaShape = CGMutablePath()
        playAreaShape.addRect(playAreaRect)
        
        let cutouts = CGMutablePath()
        cutouts.addRect(upperLeftCutout)
        cutouts.addRect(upperRightCutout)
        cutouts.addRect(lowerRightCutout)
        cutouts.addRect(lowerLeftCutout)
        playArea = playAreaShape.subtracting(cutouts, using: .winding)
        

        
//        guard virtualPlayAreaRect.width > 0, virtualPlayAreaRect.height > 0 else {
//            return CGRect(origin: .zero, size: fullSize)
//        }
//        let aspect = virtualPlayAreaRect.width / virtualPlayAreaRect.height
//        let height = min(fullSize.width / aspect, fullSize.height)
//        let width = height * aspect
//        self.playAreaRect = CGRect(x: (fullSize.width - width) / 2,
//                      y: (fullSize.height - height) / 2,
//                      width: width, height: height)
    }

    /// THE slot pad footprint test: whether `point` lies inside the pad
    /// IMAGE's ellipse (tower_slot_width × tower_slot_height) centred at `slot`, all in
    /// canvas units. The pad art is a wide ellipse, so a circle of its
    /// width-radius overreaches it above and below — every surface that
    /// asks "is this on the pad" (the editor's hit test and its slot-spacing
    /// check) uses this and not a circle or the touch target.
    public func slotFootprintContains(_ point: CGPoint, slot: CGPoint) -> Bool {
        let a = towerSlotSize.width / 2, b = towerSlotSize.height / 2
        guard a > 0, b > 0 else { return false }
        let dx = (point.x - slot.x) / a, dy = (point.y - slot.y) / b
        return dx * dx + dy * dy <= 1
    }

    /// Whether two slot pad footprints overlap: the pads' ellipses touch or
    /// cross. Same axes as `slotFootprintContains`, doubled, so pads placed
    /// by this test never draw over one another.
    public func slotFootprintsOverlap(_ p: CGPoint, _ q: CGPoint) -> Bool {
        let a = towerSlotSize.width, b = towerSlotSize.height
        guard a > 0, b > 0 else { return false }
        let dx = (p.x - q.x) / a, dy = (p.y - q.y) / b
        return dx * dx + dy * dy < 1
    }

//    public var cornerOcclusionAreas: [CGRect] {
//        let area = playAreaRect
//        func size(_ f: CGSize) -> CGSize { CGSize(width: area.width * f.width, height: area.height * f.height) }
//        let ul = size(upperLeftOcclusionCornerFraction)
//        let ur = size(upperRightOcclusionCornerFraction)
//        let ll = size(lowerLeftOcclusionCornerFraction)
//        let lr = size(lowerRightOcclusionCornerFraction)
//        return [
//            CGRect(x: area.minX, y: area.minY, width: ll.width, height: ll.height),
//            CGRect(x: area.maxX - lr.width, y: area.minY, width: lr.width, height: lr.height),
//            CGRect(x: area.minX, y: area.maxY - ul.height, width: ul.width, height: ul.height),
//            CGRect(x: area.maxX - ur.width, y: area.maxY - ur.height, width: ur.width, height: ur.height),
//        ]
//    }

    /// Convert a y measured from the top of the canvas into this space, or back
    /// again - the transform is its own inverse. Only rendering layers that draw
    /// into a y-down surface should need this.
    public func flipY(_ y: Double) -> Double { size.height - y }

    /// The rect the play area occupies on a screen of `fullSize`: the play
    /// area's own aspect, fitted and centred. The one place the on-screen
    /// playable rectangle is computed.
//    public func playableRect(in fullSize: CGSize) -> CGRect {
//        
//    }

//    public var playAreaShape: CGPath {
//        let play = playAreaRect
//        // Cuts extend past the boundary so subtraction removes the shared edge cleanly.
//        let pad = 6.0
//        let shape = CGMutablePath()
//        shape.addRect(play)
//        let cuts = CGMutablePath()
//        for cutout in cornerCutoutAreas {
//            
//            cuts.addRect(cutout)
//        }
//        return shape.subtracting(cuts, using: .winding)
//    }
}
