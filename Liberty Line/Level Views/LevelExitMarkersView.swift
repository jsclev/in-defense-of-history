import SwiftUI

/// Noninteractive ground markers centered on the GeoJSON's canonical exit points.
struct LevelExitMarkersView: View {
    let positions: [CGPoint]
    let projection: LevelMapProjection
    let spriteSize: CGFloat

    var body: some View {
        ForEach(positions.indices, id: \.self) { index in
            let layout = ExitMarkerLayout(position: positions[index], projection: projection,
                                          spriteSize: spriteSize)
            Image("path_exit_crown")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: layout.frame.width, height: layout.frame.height)
                .position(x: layout.frame.midX, y: layout.frame.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
