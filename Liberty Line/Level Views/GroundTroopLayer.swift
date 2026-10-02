import SwiftUI

/// Both armies share ground-depth ordering. Drawing the entire friendly army
/// last used to hide a living enemy when the combatants overlapped.
struct GroundTroopLayer: View {
    let presentation: BattlePresentation
    let interpolation: Double
    let militia: [BattleEngine.MilitiaSoldier]
    let sprites: MapSpriteScale
    let projection: LevelMapProjection
    var seconds: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(presentation.walkers) { walker in
                if let boss = walker.boss, let target = boss.barrageTarget,
                   let start = boss.barrageStartedAtTick, let end = boss.barrageImpactAtTick {
                    let progress = min(1, max(0, (seconds / SimClock.dt - Double(start)) / Double(end - start)))
                    let diameter = projection.viewLength(boss.rules.barrageRadius * 2)
                    Circle()
                        .fill(Color.red.opacity(0.2 + 0.25 * progress))
                        .overlay(Circle().stroke(Color.red, lineWidth: 3))
                        .frame(width: diameter, height: diameter)
                        .position(projection.viewPoint(CGPoint(x: target.x, y: target.y)))
                        .accessibilityLabel("Incoming enemy artillery")
                }
            }
            ForEach(presentation.displayedWalkers(alpha: interpolation)) { walker in
                let height = sprites.points(MapSpriteSizing.walker) * walker.presentationScale
                let foot = projection.viewPoint(walker.position)
                ZStack(alignment: .topLeading) {
                    EnemyMoraleSprite(assetName: walker.assetName, morale: walker.morale, height: height)
                        .position(x: foot.x, y: foot.y - height / 2)
                    health(walker.health, at: foot, height: height,
                           fill: walker.boss == nil ? .green : .orange,
                           scale: walker.presentationScale, showsWhenFull: walker.boss != nil)
                    if let call = walker.reinforcementCall, call.signalStartTick != nil {
                        signalProgress(call.signalProgress, at: foot, height: height)
                    }
                }
                .opacity(walker.presentationOpacity)
                .zIndex(Double(foot.y) + 0.001)
            }
            ForEach(militia) { soldier in
                let height = sprites.points(MapSpriteSizing.meleeUnit)
                let foot = projection.viewPoint(soldier.position)
                ZStack(alignment: .topLeading) {
                    Image(soldier.assetName).resizable().scaledToFit().frame(height: height)
                        .position(x: foot.x, y: foot.y - height / 2)
                    health(soldier.health, at: foot, height: height, fill: .blue)
                }
                .zIndex(Double(foot.y))
            }
        }
        .allowsHitTesting(false)
    }

    private func health(_ health: UnitHealth, at foot: CGPoint, height: CGFloat, fill: Color,
                        scale: Double = 1, showsWhenFull: Bool = false) -> some View {
        UnitHealthBar(health: health, width: sprites.points(MapSpriteSizing.healthBarWidth) * scale,
                      height: sprites.points(MapSpriteSizing.healthBarHeight), fill: fill,
                      showsWhenFull: showsWhenFull)
            .position(x: foot.x, y: foot.y - height - sprites.points(MapSpriteSizing.walkerLabelLift))
    }

    private func signalProgress(_ progress: Double, at foot: CGPoint, height: CGFloat) -> some View {
        let width = height * 0.85
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.black)
            Capsule().fill(Color.orange).frame(width: width * progress)
        }
        .frame(width: width, height: sprites.points(MapSpriteSizing.healthBarHeight))
        .position(x: foot.x, y: foot.y + sprites.points(MapSpriteSizing.healthBarHeight))
        .accessibilityLabel("Enemy signalling reinforcements")
    }
}
