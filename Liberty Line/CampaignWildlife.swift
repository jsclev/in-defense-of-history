import SwiftUI

struct CampaignCritter: View {
    struct Species {
        var framePrefix: String
        var frameCount: Int
        var framesPerSecond: Double
        var startImagePoint: CGPoint
        var widthFraction: CGFloat
        var speedFraction: CGFloat
        var restSeconds: Double
        var phaseOffset: Double
    }

    var species: Species
    var viewSize: CGSize

    private static let fadeInSeconds: Double = 1.0

    var body: some View {
        let start = CampaignMapLayout.viewPoint(
            forImagePoint: species.startImagePoint,
            imageSize: CampaignMapAsset.imageSize,
            safeRect: CampaignMapAsset.safeRect,
            viewSize: viewSize
        )
        let width = viewSize.width * species.widthFraction
        let sprite = UIImage(named: species.framePrefix + "0")
        let height = width * (sprite?.size.height ?? 1) / (sprite?.size.width ?? 1)

        let travel = start.x + width / 2 + 4
        let speed = viewSize.width * species.speedFraction
        let runSeconds = Double(travel / max(speed, 1))
        let cycle = runSeconds + species.restSeconds

        return Group {
            if sprite != nil, travel > 0, start.y > height, start.y < viewSize.height {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        + species.phaseOffset
                    let phase = elapsed.truncatingRemainder(dividingBy: cycle)
                    let running = phase < runSeconds
                    let progress = running ? phase / runSeconds : 1
                    let frame = Int(elapsed * species.framesPerSecond) % species.frameCount

                    Image(species.framePrefix + "\(frame)")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .scaleEffect(x: -1)
                        .frame(width: width, height: height)
                        .shadow(color: .black.opacity(0.3),
                                radius: width * 0.05, y: height * 0.06)
                        .opacity(running ? min(1, phase / Self.fadeInSeconds) : 0)
                        .position(x: start.x - travel * CGFloat(progress), y: start.y)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

struct CampaignAnchoredSprite: View {
    struct Kind {
        var framePrefix: String
        var frameCount: Int
        var framesPerSecond: Double
        var imagePosition: CGPoint
        var widthFraction: CGFloat
    }

    var kind: Kind
    var viewSize: CGSize
    var center: CGPoint? = nil

    var body: some View {
        let center = center ?? CampaignMapLayout.viewPoint(
            forImagePoint: kind.imagePosition,
            imageSize: CampaignMapAsset.imageSize,
            safeRect: CampaignMapAsset.safeRect,
            viewSize: viewSize
        )
        let width = viewSize.width * kind.widthFraction
        let sprite = UIImage(named: kind.framePrefix + "0")
        let height = width * (sprite?.size.height ?? 1) / (sprite?.size.width ?? 1)

        return Group {
            if sprite != nil {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let frame = Int(elapsed * kind.framesPerSecond) % kind.frameCount
                    Image(kind.framePrefix + "\(frame)")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .position(center)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
