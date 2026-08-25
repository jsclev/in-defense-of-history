import SwiftUI

@available(iOS 26.0, *)
struct HudBottomSectionView: View {
    private let runtimeCanvas: RuntimeCanvas
    private let db: Db

    @AppStorage(Constants.debugModeKey) private var debugMode = false
    
    public init(runtimeCanvas: RuntimeCanvas, db: Db) {
        self.runtimeCanvas = runtimeCanvas
        self.db = db
    }

    var body: some View {
        HStack(alignment: .bottom) {
            HudHeroesBarView(runtimeCanvas: runtimeCanvas, db: db)
            Spacer()
            HudMiscView(runtimeCanvas: runtimeCanvas)
        }
        .border(debugMode ? Color.purple : Color.clear, width: debugMode ? 1 : 0)
    }
}
