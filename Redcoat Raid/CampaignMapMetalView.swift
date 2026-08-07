import SwiftUI
import MetalKit

/// Hosts the Metal-rendered campaign map inside SwiftUI.
///
/// This is deliberately a thin adapter: all the actual Metal setup and
/// drawing lives in `Renderer`. SwiftUI owns layout, and this just keeps
/// the `Renderer` alive for as long as the view is on screen.
@available(iOS 26.0, *)
struct CampaignMapMetalView: UIViewRepresentable {
    final class Coordinator {
        var renderer: Renderer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is unavailable on this device.")
        }

        guard device.supportsFamily(.metal4) else {
            fatalError("This device doesn't support Metal 4.")
        }

        let metalView = MTKView(frame: .zero, device: device)
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.depthStencilPixelFormat = .invalid

        metalView.clearColor = MTLClearColor(
            red: 0.02,
            green: 0.03,
            blue: 0.05,
            alpha: 1.0
        )

        // The campaign map is static, so render only when requested.
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true

        do {
            let renderer = try Renderer(
                view: metalView,
                imageName: CampaignMapAsset.imageName
            )

            metalView.delegate = renderer
            context.coordinator.renderer = renderer
        } catch {
            fatalError(
                "Metal renderer creation failed: "
                + error.localizedDescription
            )
        }

        metalView.setNeedsDisplay()

        return metalView
    }

    func updateUIView(_ metalView: MTKView, context: Context) {
        // SwiftUI resizing the view already triggers
        // mtkView(_:drawableSizeWillChange:), which redraws on-demand
        // views itself — nothing to do here.
    }
}
