import SwiftUI
import UIKit

struct ScreenGeometryGate<Content: View>: View {
    let virtualCanvas: VirtualCanvas
    @ViewBuilder let content: (RuntimeCanvas) -> Content

    @State private var runtimeCanvas: RuntimeCanvas?

    var body: some View {
        if let runtimeCanvas {
            content(runtimeCanvas)
                .ignoresSafeArea()
        } else {
            GeometryReader { geometry in
                let insets = geometry.safeAreaInsets
                let physicalRect = CGRect(origin: .zero, size: geometry.size)
                let safeInsetsRect = CGRect(x: insets.leading,
                                            y: insets.top,
                                            width: physicalRect.width - insets.leading - insets.trailing,
                                            height: physicalRect.height - insets.top - insets.bottom)
                Color.clear
                    .onAppear {
                        runtimeCanvas = RuntimeCanvas(virtualCanvas: virtualCanvas,
                                                physicalRect: physicalRect,
                                                safeInsetsRect: safeInsetsRect)
                    }
            }
            .ignoresSafeArea()
        }
    }
}
