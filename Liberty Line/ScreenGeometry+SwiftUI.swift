import SwiftUI
import UIKit

struct ScreenGeometryGate<Content: View>: View {
    let virtualCanvas: VirtualCanvas
    @ViewBuilder let content: (RuntimeCanvas) -> Content

    @State private var measurement: WindowGeometryReport?

    var body: some View {
        ScreenCanvas {
            if let measurement {
                let runtimeCanvas = RuntimeCanvas(
                    virtualCanvas: virtualCanvas,
                    physicalRect: measurement.windowBounds,
                    safeInsetsRect: measurement.safeRect)
                RuntimeCanvasView(runtimeCanvas: runtimeCanvas) {
                    content(runtimeCanvas)
                }
            }
        }
        // Keep the observer mounted after the first measurement. Rotation,
        // window resizing, and safe-area changes must update the same subtree
        // without recreating the game runner or navigation state.
        .background {
            WindowReader(onWindow: { _ in }, onReport: { report in
                guard report.windowBounds.width > 0, report.windowBounds.height > 0,
                      report.safeRect.width > 0, report.safeRect.height > 0 else { return }
                if measurement?.windowBounds != report.windowBounds
                    || measurement?.safeRect != report.safeRect {
                    measurement = report
                }
            })
            .ignoresSafeArea()
        }
    }
}
