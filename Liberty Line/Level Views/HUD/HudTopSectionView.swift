import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionView: View {
    let screenGeometry: ScreenGeometry
    let runner: LevelRunner

    var body: some View {
        HStack(alignment: .top) {
            HudTopSectionLeftView(screen: screenGeometry, runner: runner)
            Spacer()
            HudTopSectionRightView(screenGeometry: screenGeometry)
        }
    }
}
