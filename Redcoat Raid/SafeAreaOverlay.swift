import SwiftUI

enum SafeAreaOverlay {
    static let defaultsKey = "showSafeAreaOverlay"

    static let physical = Color(red: 1.0, green: 0.16, blue: 0.16)
    static let safe = Color(red: 0.18, green: 1.0, blue: 0.33)
    static let playable = Color(red: 1.0, green: 0.68, blue: 0.06)

    static let physicalWidth: CGFloat = 9
    static let playableWidth: CGFloat = 6
    static let safeWidth: CGFloat = 3
}

struct SafeAreaOverlayView: View {
    var screen: ScreenGeometry

    private var fullSize: CGSize { screen.physical.size }
    private var safeRect: CGRect { screen.safe }
    private var insets: EdgeInsets {
        EdgeInsets(top: screen.safeAreaInset(.top),
                   leading: screen.safeAreaInset(.leading),
                   bottom: screen.safeAreaInset(.bottom),
                   trailing: screen.safeAreaInset(.trailing))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            border(screen.physical, SafeAreaOverlay.physical,
                   SafeAreaOverlay.physicalWidth)
            border(screen.playable, SafeAreaOverlay.playable,
                   SafeAreaOverlay.playableWidth, dashed: true)
            border(safeRect, SafeAreaOverlay.safe, SafeAreaOverlay.safeWidth)

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

    private func fmt(_ v: CGFloat) -> String { String(format: "%.0f", v) }

    private func inset(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: Typography.size(11), weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(SafeAreaOverlay.safe.opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 3))
            .position(point)
    }
}
