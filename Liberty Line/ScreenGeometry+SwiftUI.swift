import SwiftUI
import UIKit

extension View {
    func hudAnchored(_ corner: HudCorner,
                     margin: CGFloat,
                     size: CGSize = .zero,
                     in geometry: ScreenGeometry) -> some View {
        let frame = HudPlacementSolver.frame(size: size, corner: corner,
                                             margin: margin, in: geometry)
        return self
            .offset(x: frame.minX, y: frame.minY)
            .frame(width: geometry.physicalRect.width, height: geometry.physicalRect.height,
                   alignment: .topLeading)
    }
}

extension View {
    func hudFrame(_ rect: CGRect, in geometry: ScreenGeometry,
                  alignment: Alignment = .center) -> some View {
        self.frame(width: rect.width, height: rect.height, alignment: alignment)
            .offset(x: rect.minX, y: rect.minY)
            .frame(width: geometry.physicalRect.width, height: geometry.physicalRect.height,
                   alignment: .topLeading)
    }
}

struct ScreenGeometryGate<Content: View>: View {
    let virtualCanvas: VirtualCanvas
    @ViewBuilder let content: (ScreenGeometry) -> Content

    @State private var window: UIWindow?
    @State private var screen: ScreenGeometry?

    var body: some View {
        if let screen {
            content(screen)
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
