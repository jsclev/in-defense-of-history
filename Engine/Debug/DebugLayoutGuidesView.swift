import SwiftUI

public struct DebugLayoutGuidesView: View {
    private let physicalLineWidth: CGFloat = 9
    private let playAreaLineWidth: CGFloat = 6
    private let safeInsetsLineWidth: CGFloat = 3
    
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
        ZStack(alignment: .topLeading) {
            border(screen.physical, physicalColor,
                   physicalLineWidth)
            playAreaGuide
            border(safeRect, safeInsetsColor, safeInsetsLineWidth)

            inset("L \(fmt(insets.leading))", at: CGPoint(x: insets.leading / 2, y: safeRect.midY))
            inset("R \(fmt(insets.trailing))",
                  at: CGPoint(x: fullSize.width - insets.trailing / 2, y: safeRect.midY))
            inset("T \(fmt(insets.top))", at: CGPoint(x: safeRect.midX, y: insets.top / 2))
            inset("B \(fmt(insets.bottom))",
                  at: CGPoint(x: safeRect.midX, y: fullSize.height - insets.bottom / 2))
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

    @ViewBuilder private var playAreaGuide: some View {
        let projection = LevelMapArt.projection(canvasSpec: canvasSpec, fitting: screen.playable)
        SwiftUI.Path(canvasSpec.playAreaShape)
            .applying(projection.viewTransform)
            .stroke(playAreaColor,
                    style: StrokeStyle(lineWidth: playAreaLineWidth,
                                       dash: [16, 10]))
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
