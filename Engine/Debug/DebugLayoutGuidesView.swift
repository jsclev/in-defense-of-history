import SwiftUI
import UIKit

public struct DebugLayoutGuidesView: View {
    private let screen: ScreenGeometry
    private let lineThickness: Int = 3

    private let physicalRectDash: [CGFloat] = [16, 9]
    private let safeInsetsRectDash: [CGFloat] = [16, 9]
    private let hudRectDash: [CGFloat] = [16, 9]
    private let playAreaRectDash: [CGFloat] = [6, 10]
    private let playAreaDash: [CGFloat] = [6, 10]

    private let physicalRectGuideColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let safeInsetsRectGuideColor = Color(red: 0.18, green: 1.0, blue: 0.33)
    private let hudRectGuideColor = Color(red: 1.0, green: 0.8, blue: 0.0)
    private let playAreaRectGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)
    private let playAreaGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)

    public init(screen: ScreenGeometry) {
        self.screen = screen
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            createRectView(rect: screen.physicalRect,
                           borderColor: physicalRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: physicalRectDash)
            createRectView(rect: screen.safeInsetsRect,
                           borderColor: safeInsetsRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: safeInsetsRectDash)
            createRectView(rect: screen.hudRect,
                           borderColor: hudRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: hudRectDash)
            createRectView(rect: screen.playAreaRect,
                           borderColor: playAreaRectGuideColor,
                           borderThickness: lineThickness,
                           borderDash: playAreaRectDash)
            createPlayAreaView()
        }
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
