import SwiftUI

public struct DebugLayoutGuidesView: View {
    private let lineWidth: CGFloat = 2

    /// Every guide draws at its TRUE position. Where edges coincide the
    /// lines share pixels, so each rect gets its own dash pattern: solid
    /// physical underneath, long-dash safe, short-dash playable on top —
    /// all three colors stay readable on a shared edge.
    private let safeDash: [CGFloat] = [12, 8]
    private let playableDash: [CGFloat] = [4, 10]

    /// Inset labels stay fully on-screen even when their inset is zero.
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
        ZStack(alignment: .topLeading) {
            border(screen.physical, physicalColor, lineWidth)
            border(safeRect, safeInsetsColor, lineWidth, dash: safeDash)
            playAreaGuide

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

            readout
                .position(x: fullSize.width / 2, y: fullSize.height * 0.62)
        }
        .frame(width: fullSize.width, height: fullSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func border(_ rect: CGRect, _ color: Color, _ width: CGFloat,
                        dash: [CGFloat] = []) -> some View {
        Rectangle()
            .strokeBorder(color, style: StrokeStyle(lineWidth: width, dash: dash))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    @ViewBuilder private var playAreaGuide: some View {
        let projection = LevelMapArt.projection(canvasSpec: canvasSpec, fitting: screen.playable)
        SwiftUI.Path(canvasSpec.playAreaShape)
            .applying(projection.viewTransform)
            .stroke(playAreaColor,
                    style: StrokeStyle(lineWidth: lineWidth,
                                       dash: playableDash))
    }

    private func fmt(_ v: CGFloat) -> String { String(format: "%.0f", v) }

    private func fmt(_ r: CGRect) -> String {
        "(\(fmt(r.minX)), \(fmt(r.minY)))  \(fmt(r.width)) × \(fmt(r.height))"
    }

    /// The measured values themselves, so "is the math right" can be read
    /// straight off the device.
    private var readout: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("physical  \(fmt(screen.physical))").foregroundStyle(physicalColor)
            Text("safe      \(fmt(safeRect))").foregroundStyle(safeInsetsColor)
            Text("insets    L \(fmt(insets.leading))  R \(fmt(insets.trailing))  T \(fmt(insets.top))  B \(fmt(insets.bottom))")
                .foregroundStyle(safeInsetsColor)
            Text("playable  \(fmt(screen.playable))").foregroundStyle(playAreaColor)
        }
        .font(.system(size: Typography.size(13), weight: .bold, design: .monospaced))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
    }

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
