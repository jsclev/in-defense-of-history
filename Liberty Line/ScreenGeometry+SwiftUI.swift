import SwiftUI
import UIKit

struct ScreenGeometryGate<Content: View>: View {
    let virtualCanvas: VirtualCanvas
    @ViewBuilder let content: (ScreenGeometry) -> Content

    @State private var window: UIWindow?
    @State private var screen: ScreenGeometry?

    var body: some View {
        if let screen {
            content(screen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        } else {
            GeometryReader { geometry in
                if let window {
                    let frame = geometry.frame(in: .global)
                    let safeInsets = window.safeAreaInsets
                    let safeInsetsRect = CGRect(x: safeInsets.left,
                                                y: frame.minY,
                                                width: frame.width - safeInsets.right - safeInsets.left,
                                                height: frame.height - safeInsets.bottom)
                    Color.clear
                        .onAppear {
                            screen = ScreenGeometry(virtualCanvas: virtualCanvas,
                                                    physicalRect: window.bounds,
                                                    safeInsetsRect: safeInsetsRect)
                        }
                }
            }
            .ignoresSafeArea()
            .background(WindowReader(onWindow: { window = $0 },
                                     onReport: { _ in }))
        }
    }
}
