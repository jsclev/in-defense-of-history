import SwiftUI

/// Canonical projectile art, sizing and interpolation in levels and previews.
struct ProjectileLayer: View {
    let presentation: BattlePresentation
    let interpolation: Double
    let sprites: MapSpriteScale
    let projection: LevelMapProjection

    var body: some View {
        ForEach(presentation.projectiles) { projectile in
            if let assetName = projectile.kind.projectileAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: sprites.points(projectile.kind.projectileHeight)
                           * (projectile.grapeshot == nil ? 1 : 0.45))
                    .rotationEffect(.radians(projectile.heading))
                    .position(projection.viewPoint(presentation.displayedPosition(
                        of: projectile, alpha: interpolation)))
            }
        }
        .allowsHitTesting(false)
    }
}
