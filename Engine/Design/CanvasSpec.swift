import Foundation
import CoreGraphics

/// The values in the canvas_spec table: the one virtual coordinate system
/// shared by the LevelEditor, the Simulator and the game, and the footprint
/// every tower slot renders at.
///
/// Origin is the LOWER-LEFT corner of the canvas, +x runs right and +y runs
/// UP. Every stored coordinate - path points, tower slots, the playable rect -
/// is in this space, and tower ranges, radii and slot footprints are in these
/// same units. Nothing rescales on the way in or out.
public struct CanvasSpecValues: Equatable, Sendable {
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let playableRect: CGRect
    public let slotSize: CGSize

    public init(canvasWidth: Double, canvasHeight: Double,
                playableRect: CGRect, slotSize: CGSize) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.playableRect = playableRect
        self.slotSize = slotSize
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
    public static var playable: CGRect { values.playableRect }
    public static var slotSize: CGSize { values.slotSize }

    public static var size: CGSize { CGSize(width: width, height: height) }

    /// Convert a y measured from the top of the canvas into this space, or back
    /// again - the transform is its own inverse. Only rendering layers that draw
    /// into a y-down surface should need this.
    public static func flipY(_ y: Double) -> Double { height - y }
}
