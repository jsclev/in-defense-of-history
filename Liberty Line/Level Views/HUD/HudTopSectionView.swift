import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionView: View {
    let screen: ScreenGeometry

    var body: some View {
        HStack {
            HudTopSectionLeftView(screen: screen)
            Spacer()
            HudTopSectionRightView(screen: screen)
        }
    }
}
