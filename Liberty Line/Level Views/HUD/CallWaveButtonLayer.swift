import SwiftUI

/// Wave controls in the ordinary HUD, beneath any live presentations. Empty
/// space remains available to the map; only authored circles handle input.
struct CallWaveButtonLayer: View {
    let runtimeCanvas: RuntimeCanvas
    let positions: [Point]
    let waveNumber: Int
    let countdownSeconds: Int?
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(positions.enumerated()), id: \.offset) { _, point in
                CallWaveButtonView(
                    layout: CallWaveButtonLayout(position: point, runtimeCanvas: runtimeCanvas),
                    waveNumber: waveNumber, countdownSeconds: countdownSeconds, action: action)
            }
        }
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height,
               alignment: .topLeading)
    }
}
