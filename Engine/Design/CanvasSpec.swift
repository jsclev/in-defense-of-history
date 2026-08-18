import Foundation
import CoreGraphics

/// The values in the canvas_spec table: the one virtual coordinate system
/// shared by the LevelEditor, the Simulator and the game, and the footprint
/// every tower slot renders at.
///
/// Origin is the LOWER-LEFT corner of the canvas, +x runs right and +y runs
/// UP. Every stored coordinate - path points, tower slots, the play area -
/// is in this space, and tower ranges, radii and slot footprints are in these
/// same units. Nothing rescales on the way in or out.
//public struct CanvasSpecValues: Equatable, Sendable {
//    public let canvasWidth: Double
//    public let canvasHeight: Double
//    public let playArea: CGRect
//    public let slotSize: CGSize
//    public let pathWidth: Double
//    public let upperLeftOcclusionCornerFraction: CGSize
//    public let upperRightOcclusionCornerFraction: CGSize
//    public let lowerLeftOcclusionCornerFraction: CGSize
//    public let lowerRightOcclusionCornerFraction: CGSize
//
//    public init(canvasWidth: Double, canvasHeight: Double,
//                playArea: CGRect, slotSize: CGSize, pathWidth: Double,
//                upperLeftOcclusionCornerFraction: CGSize,
//                upperRightOcclusionCornerFraction: CGSize,
//                lowerLeftOcclusionCornerFraction: CGSize,
//                lowerRightOcclusionCornerFraction: CGSize) {
//        self.canvasWidth = canvasWidth
//        self.canvasHeight = canvasHeight
//        self.playArea = playArea
//        self.slotSize = slotSize
//        self.pathWidth = pathWidth
//        self.upperLeftOcclusionCornerFraction = upperLeftOcclusionCornerFraction
//        self.upperRightOcclusionCornerFraction = upperRightOcclusionCornerFraction
//        self.lowerLeftOcclusionCornerFraction = lowerLeftOcclusionCornerFraction
//        self.lowerRightOcclusionCornerFraction = lowerRightOcclusionCornerFraction
//    }
//}

public struct CanvasSpec {
    
    public init(size: CGSize,
                playAreaRect: CGRect,
                pathWidth: Double,
                towerSlotSize: CGSize,
                upperLeftOcclusionCornerFraction: CGSize,
                upperRightOcclusionCornerFraction: CGSize,
                lowerLeftOcclusionCornerFraction: CGSize,
                lowerRightOcclusionCornerFraction: CGSize) {
        self.size = size
        self.playAreaRect = playAreaRect
        self.pathWidth = pathWidth
        self.towerSlotSize = towerSlotSize
        self.upperLeftOcclusionCornerFraction = upperLeftOcclusionCornerFraction
        self.upperRightOcclusionCornerFraction = upperRightOcclusionCornerFraction
        self.lowerLeftOcclusionCornerFraction = lowerLeftOcclusionCornerFraction
        self.lowerRightOcclusionCornerFraction = lowerRightOcclusionCornerFraction
    }
    
    /// Written once per Db open, read-only everywhere else.
//    nonisolated(unsafe) private static var loaded: CanvasSpecValues?

//    public static func load(_ values: CanvasSpecValues) { loaded = values }

//    public static var isLoaded: Bool { loaded != nil }

//    private static var values: CanvasSpecValues {
//        guard let loaded else {
//            preconditionFailure(
//                "CanvasSpec read before any database was opened - construct a Db first")
//        }
//        return loaded
//    }
    public let size: CGSize
    public let pathWidth: Double

    public let playAreaRect: CGRect
    public let towerSlotSize: CGSize
    public let upperLeftOcclusionCornerFraction: CGSize
    public let upperRightOcclusionCornerFraction: CGSize
    public let lowerLeftOcclusionCornerFraction: CGSize
    public let lowerRightOcclusionCornerFraction: CGSize

    /// THE slot pad footprint test: whether `point` lies inside the pad
    /// IMAGE's ellipse (slot_width × slot_height) centred at `slot`, all in
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

    /// The four corner occlusion areas of the play area, one per corner,
    /// sized as canvas_spec's fractions of the play area (20% of its width,
    /// 5% of its height). Occlusion art covers these bands so entrances and
    /// exits near a corner can swallow enemies cleanly.
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

    /// Convert a y measured from the top of the canvas into this space, or back
    /// again - the transform is its own inverse. Only rendering layers that draw
    /// into a y-down surface should need this.
    public func flipY(_ y: Double) -> Double { size.height - y }

    public static let playAreaLineRGB: (red: Double, green: Double, blue: Double) = (0.75, 0.15, 1.0)

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
