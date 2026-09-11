import CoreGraphics

/// Shared input projection, testable without gestures or views. HUD hit testing
/// is a presentation concern; the movement model validates the resulting map point.
struct MapDestinationInput {
    let runtimeCanvas: RuntimeCanvas
    var projection: LevelMapProjection {
        LevelMapProjection(playArea: runtimeCanvas.virtualCanvas.playAreaRect,
                           fitRect: runtimeCanvas.playAreaRect,
                           virtualCanvas: runtimeCanvas.virtualCanvas)
    }

    func mapPoint(at screenPoint: CGPoint) -> CGPoint? {
        guard screenPoint.x.isFinite, screenPoint.y.isFinite,
              runtimeCanvas.runtimePlayArea.contains(screenPoint) else { return nil }
        return projection.mapPoint(screenPoint)
    }
}
