import SwiftUI

extension ScreenGeometry {
    /// Built from a GeometryProxy that sits in a safe-area-respecting layer:
    /// its `size` excludes the insets, so the physical bounds are the two added back.
    init(proxy: GeometryProxy) {
        let insets = proxy.safeAreaInsets
        self.init(
            fullSize: CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                             height: proxy.size.height + insets.top + insets.bottom),
            leading: insets.leading, top: insets.top,
            trailing: insets.trailing, bottom: insets.bottom)
    }
}

extension View {
    /// Anchors this view to a corner of the screen using the placement rules,
    /// in physical-screen coordinates. Apply inside a layer that ignores the safe area.
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
    /// Renders this view exactly in a frame a layout type computed, in
    /// physical-screen coordinates. Pair with `.ignoresSafeArea()` on the
    /// wrapping layer so physical coordinates mean what they say.
    func hudFrame(_ rect: CGRect, in geometry: ScreenGeometry,
                  alignment: Alignment = .center) -> some View {
        self.frame(width: rect.width, height: rect.height, alignment: alignment)
            .offset(x: rect.minX, y: rect.minY)
            .frame(width: geometry.physical.width, height: geometry.physical.height,
                   alignment: .topLeading)
    }
}
