import SwiftUI
import UIKit

/// The four approved brush clumps form one canonical, irregular ground bed.
/// The authored GeoJSON road surface constrains every tier, bend and placement.
/// Enemies already follow that surface, so the mask preserves the on-road slow area.
struct EngineerObstacleView: View {
    let field: EngineerObstacleField
    let roadSurface: CGPath
    let scale: CGFloat
    var selected = false
    var isSlowingEnemies = false

    private static let artwork: UIImage = {
        guard let image = UIImage(named: "engineer_rough_ground") else {
            fatalError("Missing required game asset: engineer_rough_ground")
        }
        return image
    }()

    var body: some View {
        Image(uiImage: Self.artwork)
            .resizable()
            .frame(width: field.size.width * scale, height: field.size.height * scale)
            .shadow(color: selected ? Color(red: 0.98, green: 0.78, blue: 0.44) : .clear, radius: 2)
            .clipShape(SwiftUI.Path(roadSurface).applying(field.worldToArtwork(scale: scale)),
                       style: FillStyle(eoFill: true))
            .rotationEffect(.radians(-field.heading))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Engineer abatis")
            .accessibilityHint(isSlowingEnemies ? "Enemies are slowed while crossing the branches" : "Slows enemies crossing the branches")
            .allowsHitTesting(false)
    }
}
