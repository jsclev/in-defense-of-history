import SwiftUI

struct UnitHealthBar: View {
    let health: UnitHealth
    let width: CGFloat
    let height: CGFloat
    var fill: Color = .green

    var body: some View {
        if health.isDamaged {
            ZStack(alignment: .leading) {
                Capsule().fill(Color.red)
                Capsule().fill(fill)
                    .frame(width: width * health.fraction, height: height)
            }
            .frame(width: width, height: height)
            .background {
                Capsule().stroke(Color(red: 16 / 255.0, green: 36 / 255.0, blue: 56 / 255.0),
                                 lineWidth: height / MapSpriteSizing.healthBarHeight.minimum)
            }
        }
    }
}
