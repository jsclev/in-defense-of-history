import SwiftUI

@available(iOS 26.0, *)
public struct HudTopSectionView: View {
    private let db: Db

    let runtimeCanvas: RuntimeCanvas
    let runner: LevelRunner
//    let onSpeedUp: () -> Void
//    let onExit: () -> Void
    
    public init(db: Db, runtimeCanvas: RuntimeCanvas, runner: LevelRunner) {
        self.db = db
        self.runtimeCanvas = runtimeCanvas
        self.runner = runner
    }

    public var body: some View {
        HStack(alignment: .top) {
            HudMiscView(runtimeCanvas: runtimeCanvas)
            Spacer()
            HudStatsView(runtimeCanvas: runtimeCanvas, runner: runner)
            Spacer()
            HudHeroesBarView(runtimeCanvas: runtimeCanvas, db: db)

        }
    }
}
