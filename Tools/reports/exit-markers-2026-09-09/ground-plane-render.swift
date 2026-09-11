import AppKit
import SwiftUI
import LevelEditorFormats
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
import SwiftUI

/// Noninteractive ground markers centered on the GeoJSON's canonical exit points.
struct LevelExitMarkersView: View {
    let positions: [CGPoint]
    let projection: LevelMapProjection
    let spriteSize: CGFloat

    var body: some View {
        ForEach(positions.indices, id: \.self) { index in
            Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/path_exit_rounded_x.imageset/path_exit_rounded_x@3x.png")!)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: spriteSize, height: spriteSize)
                // The source X is face-on. Lay it on the same ground plane as
                // the range rings without changing its authored center or width.
                .scaleEffect(x: 1, y: TowerRangeOverlay.verticalFraction, anchor: .center)
                .position(projection.viewPoint(positions[index]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@main struct GroundPlaneCheck {
 @MainActor static func main() throws {
  NSApplication.shared.setActivationPolicy(.accessory)
  NSApplication.shared.finishLaunching()
  let vc = VirtualCanvas(size: CGSize(width: 2868, height: 2064), playAreaRect: CGRect(x:474,y:492,width:1920,height:1080), pathWidth:140,towerSlotSize:.zero,towerMenuTotalSize:.zero,statsViewSizeFraction:.zero,masterControlsSizeFraction:.zero,heroBarSizeFraction:.zero,miscViewSizeFraction:.zero)
  let fit=CGRect(x:160-340*16/9/2,y:100-170,width:340*16/9,height:340)
  let projection=LevelMapProjection(playArea:vc.playAreaRect,fitRect:fit,virtualCanvas:vc)
  let side=MapSpriteSizing.exitMarker.resolved(playableHeightOnScreen:340)
  for d in [CGFloat(1),2,3] {
   let renderer=ImageRenderer(content:ZStack(alignment:.topLeading){Color.clear;LevelExitMarkersView(positions:[CGPoint(x:1434,y:1032)],projection:projection,spriteSize:side)}.frame(width:320,height:200))
   renderer.scale=d
   let data=NSBitmapImageRep(cgImage:renderer.cgImage!).representation(using:.png,properties:[:])!
   try data.write(to:URL(fileURLWithPath:"/Users/john/projects/td/in-defense-of-history/Tools/reports/exit-markers-2026-09-09").appendingPathComponent("ground-plane@\(Int(d))x.png"))
  }
 }
}
