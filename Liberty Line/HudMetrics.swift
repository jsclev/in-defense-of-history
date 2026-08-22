import SwiftUI

struct HudMetrics {
    let scale: CGFloat

    init(viewSize: CGSize, virtualCanvas: VirtualCanvas) {
        scale = HudScale(viewSize: viewSize, virtualCanvas: virtualCanvas).value
    }

    init(screen: ScreenGeometry) {
        scale = HudScale(playableHeight: screen.playAreaRect.height).value
    }

    init(scale: CGFloat) {
        self.scale = scale
    }

    var livesIconHeight: CGFloat { HudSizing.livesIcon.resolved(at: scale) }
    var livesTextSize: CGFloat { HudSizing.livesText.resolved(at: scale) }
    var livesValueWidth: CGFloat { HudSizing.livesValueWidth.resolved(at: scale) }
    var livesRowSpacing: CGFloat { HudSizing.livesRowSpacing.resolved(at: scale) }

    var moneyIconHeight: CGFloat { HudSizing.moneyIcon.resolved(at: scale) }
    var moneyTextSize: CGFloat { HudSizing.moneyText.resolved(at: scale) }
    var moneyRowSpacing: CGFloat { HudSizing.moneyRowSpacing.resolved(at: scale) }

    var waveTextSize: CGFloat { HudSizing.waveText.resolved(at: scale) }

    var rangeLegendTextSize: CGFloat { HudSizing.rangeLegendText.resolved(at: scale) }

    var statSpacing: CGFloat { HudSizing.statSpacing.resolved(at: scale) }
    var statRowSpacing: CGFloat { HudSizing.statRowSpacing.resolved(at: scale) }
    var statPanelMargin: CGFloat { HudSizing.statPanelMargin.resolved(at: scale) }
    var statPlatePadding: CGFloat { HudSizing.statPlatePadding.resolved(at: scale) }
    var statPlateCorner: CGFloat { HudSizing.statPlateCorner.resolved(at: scale) }

    var hudPadding: CGFloat { HudSizing.hudPadding.resolved(at: scale) }

    var cornerButtonSize: CGFloat { HudSizing.cornerButton.resolved(at: scale) }
    var cornerButtonSpacing: CGFloat { HudSizing.cornerButtonSpacing.resolved(at: scale) }
    var hudMargin: CGFloat { HudSizing.hudMargin.resolved(at: scale) }

    var menuButtonSize: CGFloat { HudSizing.menuButton.resolved(at: scale) }
    var menuButtonSpacing: CGFloat { HudSizing.menuButtonSpacing.resolved(at: scale) }
}

struct HudIcon: View {
    let name: String
    let height: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: height * Self.aspect(of: name), height: height)
    }

    static func aspect(of name: String) -> CGFloat {
        guard let image = UIImage(named: name), image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }
}
