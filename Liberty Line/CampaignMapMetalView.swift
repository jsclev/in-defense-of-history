import SwiftUI
import MetalKit

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
    }
}
