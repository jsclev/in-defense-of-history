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
    public let occlusionCornerFraction: CGSize

    public init(canvasWidth: Double, canvasHeight: Double,
                playArea: CGRect, slotSize: CGSize, pathWidth: Double,
                occlusionCornerFraction: CGSize) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.playArea = playArea
        self.slotSize = slotSize
        self.pathWidth = pathWidth
        self.occlusionCornerFraction = occlusionCornerFraction
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
        let w = area.width * values.occlusionCornerFraction.width
        let h = area.height * values.occlusionCornerFraction.height
        return [
            CGRect(x: area.minX, y: area.minY, width: w, height: h),
            CGRect(x: area.maxX - w, y: area.minY, width: w, height: h),
            CGRect(x: area.minX, y: area.maxY - h, width: w, height: h),
            CGRect(x: area.maxX - w, y: area.maxY - h, width: w, height: h),
        ]
    }

    /// Convert a y measured from the top of the canvas into this space, or back
    /// again - the transform is its own inverse. Only rendering layers that draw
    /// into a y-down surface should need this.
    public static func flipY(_ y: Double) -> Double { height - y }
}
