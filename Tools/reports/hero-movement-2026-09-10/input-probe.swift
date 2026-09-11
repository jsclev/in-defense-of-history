import AppKit
import SwiftUI
import LevelEditorFormats
final class InputState: ObservableObject {
 @Published var selected = false
 var tapped: CGPoint?
}
struct InputScene: View {
 @ObservedObject var state: InputState
 let runtimeCanvas: RuntimeCanvas
 @State private var stack = PresentationStack<Bool>()
 var body: some View {
  let projection = LevelMapProjection(playArea: runtimeCanvas.virtualCanvas.playAreaRect, fitRect: runtimeCanvas.playAreaRect, virtualCanvas: runtimeCanvas.virtualCanvas)
  LevelViewport(size: runtimeCanvas.physicalRect.size) { Color.green } interface: {
   Button("Hero") { state.selected.toggle() }.frame(width: 60,height: 44).position(x: 90,y: 330)
  } presentations: {
   PresentationLayers(stack: stack) { _ in
    destinationCatcher(projection: projection) { state.tapped = $0; state.selected = false }
   }
  }
  .onChange(of: state.selected, initial: true) { _, active in stack.synchronize(active ? [true] : []) }
 }
private func destinationCatcher(projection: LevelMapProjection,
                                    action: @escaping (CGPoint) -> Void) -> some View {
        // Capture map commands while keeping all reserved HUD corners tappable.
        let area = SwiftUI.Path(runtimeCanvas.runtimePlayArea)
        return area
            .fill(Color.black.opacity(0.001))
            .contentShape(area)
            .frame(width: runtimeCanvas.physicalRect.width,
                   height: runtimeCanvas.physicalRect.height, alignment: .topLeading)
            .gesture(SpatialTapGesture().onEnded { value in
                action(projection.mapPoint(value.location))
            })
    }
}
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

/// Mounted above the level's ordinary content and HUD. Each entry creates its
/// own view subtree, with the most recently opened presentation drawn last.
/// An empty stack has no presentation views or input catchers.
struct PresentationLayers<Presentation: Equatable, LayerContent: View>: View {
    let stack: PresentationStack<Presentation>
    @ViewBuilder let content: (Presentation) -> LayerContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(stack.entries) { entry in
                ZStack(alignment: .topLeading) {
                    content(entry.content)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.identity)
            }
        }
    }
}

@main struct Probe {
 @MainActor static func main() throws {
  let app=NSApplication.shared; app.setActivationPolicy(.accessory); app.finishLaunching()
  let db=Db(dbPath:"/Users/john/projects/td/in-defense-of-history/Db/in_defense_of_history.sqlite",fullRefresh:false)
  let canvas=try db.virtualCanvasDao.get()
  let rect=CGRect(x:0,y:0,width:852,height:393)
  let runtime=RuntimeCanvas(virtualCanvas:canvas,physicalRect:rect,safeInsetsRect:CGRect(x:59,y:0,width:734,height:372))
  let state=InputState()
  let host=NSHostingView(rootView:InputScene(state:state,runtimeCanvas:runtime))
  let window=NSWindow(contentRect:rect,styleMask:[.borderless],backing:.buffered,defer:false)
  window.contentView=host;window.makeKeyAndOrderFront(nil);host.layoutSubtreeIfNeeded()
  func flush() { RunLoop.main.run(until:Date(timeIntervalSinceNow:0.15)) }
  flush()
  defer { window.orderOut(nil) }
  var counter=0
  func press(_ p:CGPoint) {
   for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
    counter += 1
    window.sendEvent(NSEvent.mouseEvent(with:type,location:CGPoint(x:p.x,y:rect.height-p.y),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:counter,clickCount:1,pressure:type == .leftMouseDown ? 1:0)!)
    flush()
   }
  }
  press(CGPoint(x:90,y:330)); print("selected",state.selected)
  press(CGPoint(x:426,y:196));print("selected after path",state.selected,"tapped",String(describing:state.tapped))
  precondition(state.tapped != nil,"Production destination layer missed path tap")
 }
}
