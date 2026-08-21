import SwiftUI

extension ScreenGeometry {
    init(proxy: GeometryProxy, canvasSpec: CanvasSpec) {
        let insets = proxy.safeAreaInsets
        self.init(
            fullSize: CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                             height: proxy.size.height + insets.top + insets.bottom),
            leading: insets.leading, top: insets.top,
            trailing: insets.trailing, bottom: insets.bottom,
            canvasSpec: canvasSpec)
    }
}

/// The one place window geometry is optional: measures the screen on the
/// first frame, then hands the content a plain ScreenGeometry forever after.
/// Geometry cannot exist before the window's first layout, so the optional
/// is irreducible — this view confines it.
@available(iOS 26.0, *)
struct ScreenGeometryGate<Content: View>: View {
    let canvasSpec: CanvasSpec
    @ViewBuilder let content: (ScreenGeometry) -> Content

    @State private var screen: ScreenGeometry?

    var body: some View {
        if let screen {
            content(screen)
        } else {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { screen = ScreenGeometry(proxy: proxy, canvasSpec: canvasSpec) }
            }
        }
    }
}

extension View {
    func hudAnchored(_ corner: HudCorner,
                     margin: CGFloat,
                     size: CGSize = .zero,
                     in geometry: ScreenGeometry) -> some View {
        let frame = HudPlacementSolver.frame(size: size, corner: corner,
                                             margin: margin, in: geometry)
        return self
            .offset(x: frame.minX, y: frame.minY)
            .frame(width: geometry.physical.width, height: geometry.physical.height,
                   alignment: .topLeading)
    }
}

extension View {
    func hudFrame(_ rect: CGRect, in geometry: ScreenGeometry,
                  alignment: Alignment = .center) -> some View {
        self.frame(width: rect.width, height: rect.height, alignment: alignment)
            .offset(x: rect.minX, y: rect.minY)
            .frame(width: geometry.physical.width, height: geometry.physical.height,
                   alignment: .topLeading)
    }
}
