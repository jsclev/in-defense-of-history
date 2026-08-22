import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionRightView: View {
    private let screen: ScreenGeometry
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void
    private let buttonSize = CGSize(width: 50.0, height: 50.0)

    public init(screen: ScreenGeometry,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.screen = screen
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
    }

    var body: some View {
        HStack(spacing: buttonSize.width / 4.0) {
            button(asset: "speed_up_icon", action: onSpeedUp)
            button(asset: "pause_icon", action: onExit)
        }
    }

    private func button(asset: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: buttonSize.width, height: buttonSize.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
