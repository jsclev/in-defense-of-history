import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionView: View {
    let runtimeCanvas: RuntimeCanvas
    let runner: LevelRunner
    let onSpeedUp: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            HudTopSectionLeftView(runtimeCanvas: runtimeCanvas, runner: runner)
            Spacer()
            HudTopSectionRightView(runtimeCanvas: runtimeCanvas,
                                   onSpeedUp: onSpeedUp,
                                   onExit: onExit)
        }
    }
}
