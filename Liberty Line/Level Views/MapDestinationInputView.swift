import SwiftUI

/// Gesture capture and coordinate conversion only; the model owns valid moves.
struct MapDestinationInputView: View {
    let runtimeCanvas: RuntimeCanvas
    let onDestination: (CGPoint) -> Void

    var body: some View {
        let input = MapDestinationInput(runtimeCanvas: runtimeCanvas)
        let area = SwiftUI.Path(runtimeCanvas.runtimePlayArea)
        area.fill(Color.black.opacity(0.001))
            .contentShape(area)
            .frame(width: runtimeCanvas.physicalRect.width,
                   height: runtimeCanvas.physicalRect.height, alignment: .topLeading)
            .gesture(SpatialTapGesture().onEnded { value in
                if let point = input.mapPoint(at: value.location) { onDestination(point) }
            })
    }
}

struct HeroDestinationView: View {
    @ObservedObject var runner: LevelRunner
    let runtimeCanvas: RuntimeCanvas

    var body: some View {
        MapDestinationInputView(runtimeCanvas: runtimeCanvas) { point in
            runner.commandSelectedHero(to: point)
        }
    }
}
