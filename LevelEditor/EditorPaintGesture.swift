import Foundation
import CoreGraphics

/// Shared by the canvas and host integration tests. A gesture previews an edit
/// without touching the document, then commits once or discards it on cancel.
struct EditorPaintGesture {
    private(set) var preview: MapDraft.PaintStroke?
    private(set) var cursor: Point?
    private var transform: DesignTransform?

    var isActive: Bool { preview != nil }

    mutating func begin(at location: CGPoint, transform: DesignTransform,
                        width: Double, erases: Bool) {
        cancel()
        guard width.isFinite, width > 0, transform.scale.isFinite, transform.scale > 0,
              location.x.isFinite, location.y.isFinite else { return }
        self.transform = transform
        preview = .init(points: [], width: width, erases: erases)
        append(location)
    }

    mutating func append(_ location: CGPoint, includeFinalPoint: Bool = false) {
        guard let transform, var stroke = preview,
              location.x.isFinite, location.y.isFinite else { return }
        let p = transform.design(location)
        let point = Point(min(max(p.x, 0), transform.space.width),
                          min(max(p.y, 0), transform.space.height))
        cursor = point
        let spacing = max(0.5, 1 / max(transform.scale, 0.05))
        if let last = stroke.points.last {
            guard last != point,
                  includeFinalPoint || last.distance(to: point) >= spacing else { return }
        }
        stroke.points.append(point)
        preview = stroke
    }

    mutating func cancel() {
        preview = nil
        cursor = nil
        transform = nil
    }

    @MainActor
    @discardableResult
    mutating func commit(at finalLocation: CGPoint? = nil, to document: MapDocument,
                         mapGeometry: MapGeometry, undoManager: UndoManager?) -> MapDraft.PaintStroke? {
        defer { cancel() }
        if let finalLocation { append(finalLocation, includeFinalPoint: true) }
        guard let stroke = preview, !stroke.points.isEmpty else { return nil }
        document.edit(undoManager) { draft in
            if stroke.erases { draft.applyErase(stroke, mapGeometry: mapGeometry) }
            else { draft.roadPaint.append(stroke) }
        }
        return stroke
    }
}
