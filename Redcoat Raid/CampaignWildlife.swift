import SwiftUI

/// Animals crossing the western backcountry.
///
/// Each one enters at a fixed point in the artwork's pixel space, so it
/// tracks the map, then travels due west until it is clear off the side of
/// the screen and rests out of sight before crossing again. Distance and
/// speed are measured in view points, so a critter walks right off whatever
/// screen it is on. They are drawn beneath the callouts, so they pass behind
/// the name plates rather than fighting them.
struct CampaignCritter: View {
    struct Species {
        var framePrefix: String
        var frameCount: Int
        var framesPerSecond: Double
        /// Where it enters, in campaign-map image pixels.
        var startImagePoint: CGPoint
        /// Displayed width as a fraction of the view's width.
        var widthFraction: CGFloat
        /// Travel speed as a fraction of the view's width per second.
        var speedFraction: CGFloat
        var restSeconds: Double
        /// Staggers the species so they never set off together.
        var phaseOffset: Double

        /// Ambles west along the Virginia frontier, clear of the landmarks.
        static let grizzly = Species(
            framePrefix: "grizzly_bear_walk_",
            frameCount: 8,
            framesPerSecond: 8,
            startImagePoint: CGPoint(x: 1580, y: 1240),
            widthFraction: 0.052,
            speedFraction: 0.028,
            restSeconds: 5,
            phaseOffset: 0
        )

        /// Bolts across the open ground north of the Cumberland Gap — smaller
        /// and far quicker than the bear, on its own lane.
        static let jackrabbit = Species(
            framePrefix: "jackrabbit_run_",
            frameCount: 32,
            framesPerSecond: 30,
            startImagePoint: CGPoint(x: 1220, y: 1000),
            widthFraction: 0.029,
            speedFraction: 0.055,
            restSeconds: 6,
            phaseOffset: 7
        )
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

        // Far enough west to clear the screen edge completely.
        let travel = start.x + width / 2 + 4
        let speed = viewSize.width * species.speedFraction
        let runSeconds = Double(travel / max(speed, 1))
        let cycle = runSeconds + species.restSeconds

        return Group {
            if sprite != nil, travel > 0, start.y > height, start.y < viewSize.height {
                // 30Hz keeps the redraws well below what a display-linked
                // timeline would cost; the rabbit's own cycle is 30fps too.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        + species.phaseOffset
                    let phase = elapsed.truncatingRemainder(dividingBy: cycle)
                    let running = phase < runSeconds
                    let progress = running ? phase / runSeconds : 1
                    let frame = Int(elapsed * species.framesPerSecond) % species.frameCount

                    // Both sheets face right, so a westward run is mirrored.
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


/// A sprite that animates in place rather than travelling — the British
/// warship riding at anchor, hull bobbing while the water laps around it.
/// It is allowed to sit under the compass, so unlike the static scenery it
/// runs no collision checks at all — which means its berth has to be chosen
/// to clear the corner menu on every device by hand.
struct CampaignAnchoredSprite: View {
    struct Kind {
        var framePrefix: String
        var frameCount: Int
        var framesPerSecond: Double
        var imagePosition: CGPoint
        var widthFraction: CGFloat

        static let britishWarship = Kind(
            framePrefix: "british_warship_",
            frameCount: 64,
            framesPerSecond: 30,        // per the sheet manifest
            imagePosition: CGPoint(x: 1980, y: 1420),
            widthFraction: 0.098
        )
    }

    var kind: Kind
    var viewSize: CGSize
    /// Overrides the kind's fixed anchorage when a berth was solved at layout
    /// time; nil keeps the authored position.
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

/// Finds open water for the British warship at layout time.
///
/// The authored anchorage can end up under the menu bar or another dynamic
/// element, so the berth is solved per screen: every open-Atlantic cell of the
/// pirate's water mask is a candidate, tried nearest-first from the authored
/// spot. A berth is taken only if the hull stays in open water and its
/// on-screen rect clears every obstacle. With no valid berth the ship simply
/// stays in port — nil means don't draw it.
enum CampaignWarshipBerth {
    static func center(viewSize: CGSize, avoiding obstacles: [CGRect]) -> CGPoint? {
        let kind = CampaignAnchoredSprite.Kind.britishWarship
        guard viewSize.width > 0, viewSize.height > 0,
              let sprite = UIImage(named: kind.framePrefix + "0"),
              sprite.size.width > 0 else { return nil }
        let width = viewSize.width * kind.widthFraction
        let height = width * sprite.size.height / sprite.size.width

        let mask = CampaignPirateVoyage.mask
        let img = CampaignMapAsset.imageSize
        var cells: [CGPoint] = []
        for gy in 0..<mask.height {
            let row = Array(mask.rows[gy])
            for gx in 0..<min(mask.width, row.count) where row[gx] == "#" {
                cells.append(CGPoint(
                    x: (CGFloat(gx) + 0.5) / CGFloat(mask.width) * img.width,
                    y: (CGFloat(gy) + 0.5) / CGFloat(mask.height) * img.height))
            }
        }
        let preferred = kind.imagePosition
        cells.sort {
            hypot($0.x - preferred.x, $0.y - preferred.y)
                < hypot($1.x - preferred.x, $1.y - preferred.y)
        }

        let bounds = CGRect(origin: .zero, size: viewSize)
        for cell in cells {
            let center = CampaignMapLayout.viewPoint(
                forImagePoint: cell,
                imageSize: img,
                safeRect: CampaignMapAsset.safeRect,
                viewSize: viewSize
            )
            let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2,
                              width: width, height: height)
            guard bounds.insetBy(dx: 4, dy: 4).contains(rect) else { continue }
            guard !obstacles.contains(where: { $0.intersects(rect) }) else { continue }
            // The hull footprint has to stay in open water, not just the centre.
            let corners = [
                CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY),
            ]
            let wet = corners.allSatisfy { corner in
                mask.allows(CampaignMapLayout.imagePoint(
                    forViewPoint: corner,
                    imageSize: img,
                    safeRect: CampaignMapAsset.safeRect,
                    viewSize: viewSize), imageSize: img)
            }
            guard wet else { continue }
            return center
        }
        return nil
    }
}
