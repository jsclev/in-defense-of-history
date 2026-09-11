import CoreGraphics

struct LevelMapProjection {
    /// The virtual canvas, from virtual_canvas. Map artwork is required to be
    /// exactly this size, so the projection never asks the image.
    var canvasSize: CGSize { virtualCanvas.size }
    let playArea: CGRect
    let fitRect: CGRect
    let virtualCanvas: VirtualCanvas

    var scale: CGFloat {
        min(fitRect.width / playArea.width, fitRect.height / playArea.height)
    }

    private var origin: CGPoint {
        // y is flipped by viewPoint, so the rect's centre is measured from the
        // top of the canvas here. Written out rather than relying on the rect
        // happening to be vertically centred.
        CGPoint(
            x: fitRect.midX - playArea.midX * scale,
            y: fitRect.midY - (canvasSize.height - playArea.midY) * scale
        )
    }

    /// Canonical (lower-left origin, +y up) to SwiftUI view space (+y down).
    /// The only place the game flips.
    func viewPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale,
                y: origin.y + (canvasSize.height - p.y) * scale)
    }

    func viewLength(_ l: CGFloat) -> CGFloat { l * scale }

    func mapPoint(_ v: CGPoint) -> CGPoint {
        CGPoint(x: (v.x - origin.x) / scale,
                y: canvasSize.height - (v.y - origin.y) / scale)
    }

    var viewTransform: CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
                          tx: origin.x, ty: origin.y + canvasSize.height * scale)
    }

    var imageFrameSize: CGSize {
        CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    var imageCenter: CGPoint {
        viewPoint(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
    }
}

