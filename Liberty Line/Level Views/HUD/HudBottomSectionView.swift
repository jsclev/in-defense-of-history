import SwiftUI

@available(iOS 26.0, *)
struct HudBottomSectionView: View {
    @AppStorage(Constants.debugModeKey) private var debugMode = false
    private let db: Db
    private let screen: ScreenGeometry
    
    public init(db: Db, screen: ScreenGeometry) {
        self.db = db
        self.screen = screen
    }

    var body: some View {
        HStack {
            HudHeroesBarView(db: db, buttonSize: CGSize(width: 50.0, height: 50.0))
            Spacer()
            HudMiscView(buttonSize: CGSize(width: 50.0, height: 50.0))
        }
        .border(debugMode ? Color.purple : Color.clear, width: debugMode ? 1 : 0)
    }
}
