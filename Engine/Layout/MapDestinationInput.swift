import CoreGraphics

/// Shared input projection. Reserve the same HUD controls as the presentation;
/// the movement model validates the resulting map point.
struct MapDestinationInput {
    let runtimeCanvas: RuntimeCanvas
    var projection: LevelMapProjection {
        LevelMapProjection(playArea: runtimeCanvas.virtualCanvas.playAreaRect,
                           fitRect: runtimeCanvas.playAreaRect,
                           virtualCanvas: runtimeCanvas.virtualCanvas)
    }

    func mapPoint(at screenPoint: CGPoint) -> CGPoint? {
        guard screenPoint.x.isFinite, screenPoint.y.isFinite,
              runtimeCanvas.runtimeMapInputArea.contains(screenPoint) else { return nil }
        return projection.mapPoint(screenPoint)
    }
}
