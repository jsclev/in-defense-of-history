import Foundation
import CoreGraphics

/// The one virtual coordinate system shared by the LevelEditor, the Simulator
/// and the game.
///
/// Origin is the LOWER-LEFT corner of the canvas, +x runs right and +y runs UP.
/// Every stored coordinate - path points, tower slots, the playable rect - is in
/// this space, and tower ranges and radii are in these same units. Nothing
/// rescales on the way in or out.
///
/// The canvas is larger than the playable rect on all four sides; that margin is
/// bleed, drawn but never played in. It is vertically centred, so flipping y
/// maps the playable rect onto itself.
public enum CanvasSpec {
    public static let width = 2868.0
    public static let height = 2064.0
    public static let playable = CGRect(x: 474, y: 492, width: 1920, height: 1080)

    public static let size = CGSize(width: width, height: height)

    /// Convert a y measured from the top of the canvas into this space, or back
    /// again - the transform is its own inverse. Only rendering layers that draw
    /// into a y-down surface should need this.
    public static func flipY(_ y: Double) -> Double { height - y }
}
