import SwiftUI

extension ScreenGeometry {
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
