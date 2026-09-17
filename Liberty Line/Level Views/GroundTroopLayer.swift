import SwiftUI

/// Both armies share ground-depth ordering. Drawing the entire friendly army
/// last used to hide a living enemy when the combatants overlapped.
struct GroundTroopLayer: View {
    let walkers: [LevelRunner.Walker]
    let militia: [LevelRunner.MilitiaSoldier]
    let sprites: MapSpriteScale
    let projection: LevelMapProjection

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(walkers) { walker in
                let height = sprites.points(MapSpriteSizing.walker)
                let foot = projection.viewPoint(walker.position)
                ZStack(alignment: .topLeading) {
                    EnemyMoraleSprite(assetName: walker.assetName, morale: walker.morale, height: height)
                        .position(x: foot.x, y: foot.y - height / 2)
                    if walker.hp < walker.maxHP {
                        health(fraction: walker.hp / walker.maxHP, at: foot, height: height, fill: .green)
                    }
                }
                .zIndex(Double(foot.y) + 0.001)
            }
            ForEach(militia) { soldier in
                let height = sprites.points(MapSpriteSizing.meleeUnit)
                let foot = projection.viewPoint(soldier.position)
                ZStack(alignment: .topLeading) {
                    Image(soldier.assetName).resizable().scaledToFit().frame(height: height)
                        .position(x: foot.x, y: foot.y - height / 2)
                    if soldier.hp < soldier.maxHP {
                        health(fraction: soldier.hp / soldier.maxHP, at: foot, height: height, fill: .blue)
                    }
                }
                .zIndex(Double(foot.y))
            }
        }
        .allowsHitTesting(false)
    }

    private func health(fraction: Double, at foot: CGPoint, height: CGFloat, fill: Color) -> some View {
        UnitHealthBar(fraction: max(0, fraction), width: sprites.points(MapSpriteSizing.healthBarWidth),
                      height: sprites.points(MapSpriteSizing.healthBarHeight), fill: fill)
            .position(x: foot.x, y: foot.y - height - sprites.points(MapSpriteSizing.walkerLabelLift))
    }
}
