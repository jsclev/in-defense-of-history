import SwiftUI

@available(iOS 26.0, *)
public struct HudBottomSectionView: View {
    private let runtimeCanvas: RuntimeCanvas
//    private let db: Db
    public let onSpeedUp: () -> Void
    public let onExit: () -> Void

    @AppStorage(Constants.debugModeKey) private var debugMode = false
    
    public init(runtimeCanvas: RuntimeCanvas, db: Db, onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.runtimeCanvas = runtimeCanvas
//        self.db = db
        self.onExit = onExit
        self.onSpeedUp = onSpeedUp
    }

    public var body: some View {
        HStack(alignment: .bottom) {
            HudTopSectionRightView(runtimeCanvas: runtimeCanvas,
                                   onSpeedUp: onSpeedUp,
                                   onExit: onExit)
//            HudHeroesBarView(runtimeCanvas: runtimeCanvas, db: db)
            Spacer()
            HudMiscView(runtimeCanvas: runtimeCanvas)
            
//            Spacer()
            
            
        }
        .border(debugMode ? Color.purple : Color.clear, width: debugMode ? 1 : 0)
    }
}
