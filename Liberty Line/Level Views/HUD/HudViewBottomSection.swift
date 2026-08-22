import SwiftUI

@available(iOS 26.0, *)
struct HudViewBottomSection: View {
    @AppStorage(Constants.debugModeKey) private var debugMode = false
    let screen: ScreenGeometry

    var body: some View {
        HStack {
            HudHeroesBarView(heroes: [], buttonSize: CGSize(width: 50.0, height: 50.0))
            Spacer()
            //miscBar(metrics: metrics, screen: screen)
        }
        .border(debugMode ? Color.purple : Color.clear, width: debugMode ? 1 : 0)
    }
    
//    private func heroBar(metrics: HudMetrics, screen: ScreenGeometry) -> some View {
//        let side = HudSizing.cornerButton.resolved(at: metrics.scale) * 1.05
//        let button = CGSize(width: side, height: side)
//        let spacing = HudSizing.cornerButtonSpacing.resolved(at: metrics.scale) * 0.3696
//        let count = LevelHeroBarView.slotCount
//        let row = StackLayout.row(Array(repeating: button, count: count), spacing: spacing)
//        let frame = HudPlacementSolver.bottomLineFrame(size: row.size,
//                                                       corner: .bottomLeading,
//                                                       margin: 0.0, in: screen)
//        
//        return HudHeroesBarView(heroes: runner.selectedHeroes,
//                                buttonSize: button, spacing: spacing)
//            .hudFrame(frame, in: screen, alignment: .leading)
//    }
}
