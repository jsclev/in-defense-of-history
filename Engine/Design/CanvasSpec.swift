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
public struct CanvasSpecValues: Equatable, Sendable {
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let playArea: CGRect
    public let slotSize: CGSize
    public let pathWidth: Double
    public let upperLeftOcclusionCornerFraction: CGSize
    public let upperRightOcclusionCornerFraction: CGSize
    public let lowerLeftOcclusionCornerFraction: CGSize
    public let lowerRightOcclusionCornerFraction: CGSize

    public init(canvasWidth: Double, canvasHeight: Double,
                playArea: CGRect, slotSize: CGSize, pathWidth: Double,
                upperLeftOcclusionCornerFraction: CGSize,
                upperRightOcclusionCornerFraction: CGSize,
                lowerLeftOcclusionCornerFraction: CGSize,
                lowerRightOcclusionCornerFraction: CGSize) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.playArea = playArea
        self.slotSize = slotSize
        self.pathWidth = pathWidth
        self.upperLeftOcclusionCornerFraction = upperLeftOcclusionCornerFraction
        self.upperRightOcclusionCornerFraction = upperRightOcclusionCornerFraction
        self.lowerLeftOcclusionCornerFraction = lowerLeftOcclusionCornerFraction
        self.lowerRightOcclusionCornerFraction = lowerRightOcclusionCornerFraction
    }
}

/// Process-wide access to the loaded canvas_spec row.
///
/// No number here is written in Swift: Db.init reads the row through
/// CanvasSpecDAO the moment a connection opens, and every target - game,
/// editor, simulator - opens a Db before it draws or simulates anything.
/// Reading before any Db has opened is a programmer error and traps.
public enum CanvasSpec {
    /// Written once per Db open, read-only everywhere else.
    nonisolated(unsafe) private static var loaded: CanvasSpecValues?

    public static func load(_ values: CanvasSpecValues) { loaded = values }

    public static var isLoaded: Bool { loaded != nil }

    private static var values: CanvasSpecValues {
        guard let loaded else {
            preconditionFailure(
                "CanvasSpec read before any database was opened - construct a Db first")
        }
        return loaded
    }

    public static var width: Double { values.canvasWidth }
    public static var height: Double { values.canvasHeight }
    public static var playArea: CGRect { values.playArea }
    public static var slotSize: CGSize { values.slotSize }

    /// THE slot pad footprint test: whether `point` lies inside the pad
    /// IMAGE's ellipse (slot_width × slot_height) centred at `slot`, all in
    /// canvas units. The pad art is a wide ellipse, so a circle of its
    /// width-radius overreaches it above and below — every surface that
    /// asks "is this on the pad" (the editor's hit test and its slot-spacing
    /// check) uses this and not a circle or the touch target.
    public static func slotFootprintContains(_ point: CGPoint, slot: CGPoint) -> Bool {
        let a = slotSize.width / 2, b = slotSize.height / 2
        guard a > 0, b > 0 else { return false }
        let dx = (point.x - slot.x) / a, dy = (point.y - slot.y) / b
        return dx * dx + dy * dy <= 1
    }

    /// Whether two slot pad footprints overlap: the pads' ellipses touch or
    /// cross. Same axes as `slotFootprintContains`, doubled, so pads placed
    /// by this test never draw over one another.
    public static func slotFootprintsOverlap(_ p: CGPoint, _ q: CGPoint) -> Bool {
        let a = slotSize.width, b = slotSize.height
        guard a > 0, b > 0 else { return false }
        let dx = (p.x - q.x) / a, dy = (p.y - q.y) / b
        return dx * dx + dy * dy < 1
    }

    /// Full width of an enemy path, edge to edge. The shipped Battle Road
    /// lane and the game's lane-coverage half-width (51) both derive from
    /// this one number.
    public static var pathWidth: Double { values.pathWidth }

    public static var size: CGSize { CGSize(width: width, height: height) }

    /// The four corner occlusion areas of the play area, one per corner,
    /// sized as canvas_spec's fractions of the play area (20% of its width,
    /// 5% of its height). Occlusion art covers these bands so entrances and
    /// exits near a corner can swallow enemies cleanly.
    public static var cornerOcclusionAreas: [CGRect] {
        let area = playArea
        func size(_ f: CGSize) -> CGSize { CGSize(width: area.width * f.width, height: area.height * f.height) }
        let ul = size(values.upperLeftOcclusionCornerFraction)
        let ur = size(values.upperRightOcclusionCornerFraction)
        let ll = size(values.lowerLeftOcclusionCornerFraction)
        let lr = size(values.lowerRightOcclusionCornerFraction)
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
    public static func flipY(_ y: Double) -> Double { height - y }

    public static let playAreaLineRGB: (red: Double, green: Double, blue: Double) = (0.75, 0.15, 1.0)

    public static var playAreaShape: CGPath {
        let play = playArea
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
