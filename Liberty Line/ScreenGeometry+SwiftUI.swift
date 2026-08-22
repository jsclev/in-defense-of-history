import SwiftUI
import UIKit

struct ScreenGeometryGate<Content: View>: View {
    let virtualCanvas: VirtualCanvas
    @ViewBuilder let content: (ScreenGeometry) -> Content

    @State private var screen: ScreenGeometry?

    var body: some View {
        if let screen {
            content(screen)
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
                        screen = ScreenGeometry(virtualCanvas: virtualCanvas,
                                                physicalRect: physicalRect,
                                                safeInsetsRect: safeInsetsRect)
                    }
            }
            .ignoresSafeArea()
        }
    }
}
