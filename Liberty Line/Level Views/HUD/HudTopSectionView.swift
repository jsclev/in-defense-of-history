import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionView: View {
    let screen: ScreenGeometry
    let runner: LevelRunner
    let onSpeedUp: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack {
            HudTopSectionLeftView(screen: screen, runner: runner)
            Spacer()
            HudTopSectionRightView(screen: screen, onSpeedUp: onSpeedUp, onExit: onExit)
        }
    }
}
