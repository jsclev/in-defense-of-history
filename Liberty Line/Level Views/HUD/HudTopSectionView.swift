import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionView: View {
    let screenGeometry: ScreenGeometry
    let runner: LevelRunner
//    let onSpeedUp: () -> Void
//    let onExit: () -> Void

    var body: some View {
        HStack {
            HudTopSectionLeftView(screen: screenGeometry, runner: runner)
            Spacer()
            HudTopSectionRightView(screenGeometry: screenGeometry)
        }
    }
}
