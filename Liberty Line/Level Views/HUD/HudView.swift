import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    let screen: ScreenGeometry

    var body: some View {
        VStack {
            HudViewTopSection(screen: screen)
            Spacer()
            HudViewBottomSection(screen: screen)
        }
    }
}
