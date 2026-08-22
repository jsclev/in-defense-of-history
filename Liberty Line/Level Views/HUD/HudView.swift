import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let screen: ScreenGeometry
    
    public init(db: Db, screen: ScreenGeometry) {
        self.db = db
        self.screen = screen
    }

    var body: some View {
        VStack {
            HudTopSectionView(screen: screen)
            Spacer()
            HudBottomSectionView(db: db, screen: screen)
        }
    }
}
