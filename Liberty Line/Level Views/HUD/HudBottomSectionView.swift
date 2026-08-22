import SwiftUI

@available(iOS 26.0, *)
struct HudBottomSectionView: View {
    @AppStorage(Constants.debugModeKey) private var debugMode = false
    private let db: Db
    private let screen: ScreenGeometry
    private let buttonSize: CGFloat
    
    public init(db: Db, screen: ScreenGeometry, buttonSize: CGFloat) {
        self.db = db
        self.screen = screen
        self.buttonSize = buttonSize
    }

    var body: some View {
        HStack {
            HudHeroesBarView(db: db, buttonSize: buttonSize)
            Spacer()
            HudMiscView(buttonSize: buttonSize)
        }
        .border(debugMode ? Color.purple : Color.clear, width: debugMode ? 1 : 0)
    }
}
