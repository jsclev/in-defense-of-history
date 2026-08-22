import SwiftUI
import UIKit

public struct DebugLayoutGuidesView: View {
    private let screen: ScreenGeometry
    private let lineThickness: Int = 2

    private let physicalRectDash: [CGFloat] = [16, 9]
    private let safeInsetsDash: [CGFloat] = [16, 9]
    private let playAreaRectDash: [CGFloat] = [6, 10]
    private let playAreaDash: [CGFloat] = [6, 10]

    private let physicalGuideColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let safeInsetsGuideColor = Color(red: 0.18, green: 1.0, blue: 0.33)
    private let playAreaRectGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)
    private let playAreaGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)

    public init(screen: ScreenGeometry) {
        self.screen = screen
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            createRectView(rect: screen.physicalRect,
                           borderColor: physicalGuideColor,
                           borderThickness: lineThickness,
                           borderDash: physicalRectDash)
            createRectView(rect: screen.safeInsetsRect,
                           borderColor: safeInsetsGuideColor,
                           borderThickness: lineThickness,
                           borderDash: safeInsetsDash)
            createRectView(rect: screen.playAreaRect,
                           borderColor: playAreaRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: playAreaRectDash)
            createPlayAreaView()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func createRectView(rect: CGRect,
                                borderColor: Color,
                                borderThickness: Int,
                                borderDash: [CGFloat] = []) -> some View {
        return Rectangle()
            .strokeBorder(borderColor,
                          style: StrokeStyle(lineWidth: CGFloat(borderThickness), dash: borderDash))
            .frame(width: rect.width, height: rect.height)
            .position(
                x: rect.midX,
                y: rect.midY
            )
    }

    private func createPlayAreaView() -> some View {
        let lineStyle = StrokeStyle(lineWidth: CGFloat(lineThickness), dash: playAreaDash)
        
        return SwiftUI.Path(screen.runtimePlayArea)
            .stroke(playAreaGuideColor, style: lineStyle)
    }
}
