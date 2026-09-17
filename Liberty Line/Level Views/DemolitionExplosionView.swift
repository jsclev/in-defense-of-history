import SwiftUI
import UIKit

/// Ground wave plus a painted ignition/fire/smoke sequence, anchored at the
/// planted charge. Troops and their HP/morale cues render above this layer.
struct DemolitionBlastView: View {
    let age: Double
    let radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side = radius * 2
        ZStack {
            if let index = DemolitionExplosion.frame(at: age) {
                groundBurst
                Group {
                    if reduceMotion {
                        frame(7).opacity(0.5 * (1 - age / DemolitionExplosion.duration))
                    } else {
                        let start = index == 0 ? 0 : DemolitionExplosion.frameEnds[index - 1]
                        let end = DemolitionExplosion.frameEnds[index]
                        let blend = index < DemolitionExplosion.frameCount - 1 ? (age - start) / (end - start) : 0
                        ZStack {
                            frame(index).opacity(1 - blend)
                            if index + 1 < DemolitionExplosion.frameCount {
                                frame(index + 1).opacity(blend)
                            }
                        }
                        .opacity(DemolitionExplosion.opacity(at: age))
                    }
                }
                .frame(width: side, height: side)
                .offset(y: (0.5 - DemolitionExplosion.groundAnchorY) * side)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func frame(_ index: Int) -> some View {
        if DemolitionExplosionFrames.images.indices.contains(index) {
            Image(uiImage: DemolitionExplosionFrames.images[index])
                .resizable().interpolation(.high).scaledToFit()
        }
    }

    private var groundBurst: some View {
        Canvas { context, size in
            guard !reduceMotion, age >= 0, age < DemolitionExplosion.duration else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let fade = max(0, 1 - age / DemolitionExplosion.duration)
            let shadow = CGRect(x: center.x - radius * 0.6, y: center.y - radius * 0.24,
                                width: radius * 1.2, height: radius * 0.48)
            context.fill(SwiftUI.Path(ellipseIn: shadow),
                         with: .color(Color(red: 0.19, green: 0.14, blue: 0.13).opacity(0.3 * fade)))
            if age < 0.42 {
                let t = age / 0.42
                let spread = radius * (0.12 + 0.88 * (1 - pow(1 - t, 3)))
                let ring = CGRect(x: center.x - spread, y: center.y - spread,
                                  width: spread * 2, height: spread * 2)
                context.stroke(SwiftUI.Path(ellipseIn: ring),
                    with: .color(Color(red: 1, green: 0.77, blue: 0.35).opacity(0.85 * (1 - t))),
                    lineWidth: max(2.2, radius * 0.043))
            }
            if age < 0.12 {
                let t = age / 0.12
                let flash = radius * (0.12 + 0.16 * t)
                context.fill(SwiftUI.Path(ellipseIn: CGRect(x: center.x - flash,
                    y: center.y - flash * 0.55, width: flash * 2, height: flash * 1.1)),
                    with: .color(Color(red: 1, green: 0.95, blue: 0.70).opacity(1 - t)))
            }
        }
    }
}

/// Decode/crop once, never during the per-frame animation update.
@MainActor enum DemolitionExplosionFrames {
    static let images: [UIImage] = {
        guard let sheet = UIImage(named: DemolitionExplosion.assetName), let source = sheet.cgImage,
              source.width % DemolitionExplosion.columns == 0,
              source.height % DemolitionExplosion.rows == 0 else { return [] }
        let size = CGSize(width: source.width, height: source.height)
        var result: [UIImage] = []
        for index in 0..<DemolitionExplosion.frameCount {
            guard let rect = DemolitionExplosion.frameRect(index: index, sheetSize: size),
                  let frame = source.cropping(to: rect) else { return [] }
            result.append(UIImage(cgImage: frame, scale: sheet.scale, orientation: .up))
        }
        return result
    }()
}
