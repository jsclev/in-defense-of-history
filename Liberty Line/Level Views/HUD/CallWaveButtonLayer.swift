import SwiftUI

/// Wave controls in the ordinary HUD, beneath any live presentations. Empty
/// space remains available to the map; only authored circles handle input.
struct CallWaveButtonLayer: View {
    let runtimeCanvas: RuntimeCanvas
    let positions: [Point]
    let waveNumber: Int
    let countdownSeconds: Int?
    let selection: CallWaveButtonSelection
    let seconds: Double
    let action: (Point) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if selection.isVisible(for: waveNumber) {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, point in
                    CallWaveButtonView(
                        layout: CallWaveButtonLayout(position: point, runtimeCanvas: runtimeCanvas),
                        waveNumber: waveNumber, countdownSeconds: countdownSeconds,
                        seconds: seconds,
                        isSelected: selection.isSelected(point, for: waveNumber)) {
                        action(point)
                    }
                }
            }
        }
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height,
               alignment: .topLeading)
    }
}
