import SwiftUI

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
