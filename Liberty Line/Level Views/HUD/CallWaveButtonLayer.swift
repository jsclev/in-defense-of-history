import SwiftUI

/// Wave controls in the ordinary HUD, beneath any live presentations. Empty
/// space remains available to the map; only authored circles handle input.
struct CallWaveButtonLayer: View {
    let runtimeCanvas: RuntimeCanvas
    let positions: [Point]
    let waveNumber: Int
    let countdownSeconds: Int?
    let action: () -> Void

    @State private var selection = CallWaveButtonSelection()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if selection.isVisible(for: waveNumber) {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, point in
                    CallWaveButtonView(
                        layout: CallWaveButtonLayout(position: point, runtimeCanvas: runtimeCanvas),
                        waveNumber: waveNumber, countdownSeconds: countdownSeconds,
                        isSelected: selection.isSelected(point, for: waveNumber)) {
                        if selection.tap(point, for: waveNumber) {
                            action()
                        }
                    }
                }
            }
        }
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height,
               alignment: .topLeading)
    }
}
