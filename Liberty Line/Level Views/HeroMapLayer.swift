import SwiftUI

/// Hero art and selection controls. Positions are published by the movement model.
struct HeroMapLayer: View {
    let heroes: [LevelRunner.HeroSoldier]
    let runtimeCanvas: RuntimeCanvas
    let projection: LevelMapProjection
    let onSelect: (Int) -> Void

    var body: some View {
        let sprites = MapSpriteScale(runtimeCanvas: runtimeCanvas)
        ZStack(alignment: .topLeading) {
            ForEach(heroes) { hero in
                let footprint = HeroSpriteFootprint(baseAssetName: hero.baseAssetName,
                    aspectRatio: hero.imageAspectRatio, playableHeight: runtimeCanvas.playAreaRect.height)
                let spriteHeight = footprint.size.height
                let groundInset = footprint.groundInset
                let footPoint = projection.viewPoint(hero.position)
                if hero.isSelected {
                    Circle()
                        .stroke(Color.yellow.opacity(0.9), lineWidth: spriteHeight * 0.054)
                        .frame(width: spriteHeight * 0.8, height: spriteHeight * 0.8)
                        .position(x: footPoint.x, y: footPoint.y - spriteHeight * 0.1)
                        .allowsHitTesting(false)
                }
                Image(hero.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: footprint.size.width, height: spriteHeight)
                    .frame(minWidth: TouchTarget.minimum, minHeight: TouchTarget.minimum)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(hero.id) }
                    .position(x: footPoint.x, y: footPoint.y - spriteHeight / 2 + groundInset)

                if hero.hp < hero.maxHP {
                    let fraction = CGFloat(max(0, hero.hp / hero.maxHP))
                    let barWidth = sprites.points(MapSpriteSizing.healthBarWidth)
                    let barHeight = sprites.points(MapSpriteSizing.healthBarHeight)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.red)
                        Capsule()
                            .fill(Color.green)
                            .frame(width: barWidth * fraction, height: barHeight)
                    }
                    .frame(width: barWidth, height: barHeight)
                    .position(x: footPoint.x,
                              y: footPoint.y - spriteHeight - sprites.points(MapSpriteSizing.walkerLabelLift))
                    .allowsHitTesting(false)
                }
            }
        }
    }
}
