import SwiftUI

public struct DebugLayoutGuidesView: View {
    private let lineWidth: CGFloat = 2

    /// Keeps a nested guide visible where its true edge coincides with the
    /// guide outside it: the outer line owns the edge, the inner one sits
    /// this far inside. Priority, outermost first: physical, safe, playable.
    private let clearance: CGFloat = 8

    /// Inset labels stay fully on-screen and clear of the line band even
    /// when their inset is zero.
    private let labelFloor: CGFloat = 30

    private let physicalColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let playAreaColor = Color(red: 0.75, green: 0.15, blue: 1.0)
    private let safeInsetsColor = Color(red: 0.18, green: 1.0, blue: 0.33)

    private var fullSize: CGSize { screen.physical.size }
    private var safeRect: CGRect { screen.safe }
    private var insets: EdgeInsets {
        EdgeInsets(top: screen.safeAreaInset(.top),
                   leading: screen.safeAreaInset(.leading),
                   bottom: screen.safeAreaInset(.bottom),
                   trailing: screen.safeAreaInset(.trailing))
    }
    
    
    private var screen: ScreenGeometry
    private var canvasSpec: CanvasSpec
    
    public init(screen: ScreenGeometry, canvasSpec: CanvasSpec) {
        self.screen = screen
        self.canvasSpec = canvasSpec
    }

    public var body: some View {
        let safeDrawn = nested(safeRect, inside: screen.physical)
        let playableDrawn = nested(screen.playable, inside: safeDrawn)
        ZStack(alignment: .topLeading) {
            border(screen.physical, physicalColor, lineWidth)
            border(safeDrawn, safeInsetsColor, lineWidth)
            playAreaGuide(fitting: playableDrawn)

            inset("L \(fmt(insets.leading))",
                  at: CGPoint(x: max(insets.leading / 2, labelFloor), y: safeRect.midY))
            inset("R \(fmt(insets.trailing))",
                  at: CGPoint(x: min(fullSize.width - insets.trailing / 2,
                                     fullSize.width - labelFloor), y: safeRect.midY))
            inset("T \(fmt(insets.top))",
                  at: CGPoint(x: safeRect.midX, y: max(insets.top / 2, labelFloor)))
            inset("B \(fmt(insets.bottom))",
                  at: CGPoint(x: safeRect.midX, y: min(fullSize.height - insets.bottom / 2,
                                                       fullSize.height - labelFloor)))
        }
        .frame(width: fullSize.width, height: fullSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func border(_ rect: CGRect, _ color: Color, _ width: CGFloat,
                        dashed: Bool = false) -> some View {
        Rectangle()
            .strokeBorder(color, style: StrokeStyle(lineWidth: width,
                                                    dash: dashed ? [16, 10] : []))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    @ViewBuilder private func playAreaGuide(fitting fitRect: CGRect) -> some View {
        let projection = LevelMapArt.projection(canvasSpec: canvasSpec, fitting: fitRect)
        SwiftUI.Path(canvasSpec.playAreaShape)
            .applying(projection.viewTransform)
            .stroke(playAreaColor,
                    style: StrokeStyle(lineWidth: lineWidth,
                                       dash: [16, 10]))
    }

    private func nested(_ rect: CGRect, inside outer: CGRect) -> CGRect {
        let minX = max(rect.minX, outer.minX + clearance)
        let minY = max(rect.minY, outer.minY + clearance)
        let maxX = min(rect.maxX, outer.maxX - clearance)
        let maxY = min(rect.maxY, outer.maxY - clearance)
        return CGRect(x: minX, y: minY,
                      width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    private func fmt(_ v: CGFloat) -> String { String(format: "%.0f", v) }

    private func inset(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: Typography.size(11), weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(safeInsetsColor.opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 3))
            .position(point)
    }
}
