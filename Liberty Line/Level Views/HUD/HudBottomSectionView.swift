import SwiftUI

@available(iOS 26.0, *)
struct HudBottomSectionView: View {
    private let screenGeometry: ScreenGeometry
    private let db: Db

    @AppStorage(Constants.debugModeKey) private var debugMode = false
    
    public init(screenGeometry: ScreenGeometry, db: Db) {
        self.screenGeometry = screenGeometry
        self.db = db
    }

    var body: some View {
        HStack(alignment: .bottom) {
            HudHeroesBarView(screenGeometry: screenGeometry, db: db)
            Spacer()
            HudMiscView(screenGeometry: screenGeometry)
        }
        .border(debugMode ? Color.purple : Color.clear, width: debugMode ? 1 : 0)
    }
}
