import Foundation
import CoreGraphics

// Compile with HeroSpriteProfile, MapSpriteSizing, HudSizing and VirtualCanvas.
@main
enum HeroPhysicalScaleCheck {
    struct Record: Decodable {
        let heroes: [Hero]
        struct Hero: Decodable {
            let id: String
            let stature_inches: Double
            let evidence: String
            let calibration: Calibration
        }
        struct Calibration: Decodable {
            let normalized_canvas_height: Double
            let standing_equivalent_height: Double
            let ground_inset_fraction: Double
        }
    }

    static func near(_ a: CGFloat, _ b: CGFloat) {
        precondition(abs(a - b) < 0.000001, "Mismatch: \(a) versus \(b)")
    }

    static func main() throws {
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf:
            URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Tools/hero_physical_scale.json")))
        precondition(Set(record.heroes.map { "hero_unit_" + $0.id }) == Set(HeroSpriteProfile.all.keys))
        let washington = HeroSpriteProfile.all["hero_unit_george_washington"]!
        near(washington.imageHeight.resolved(playableHeightOnScreen: 340)
             * washington.standingBodyFraction, 38.038)
        var output: [[String: Any]] = []
        for row in record.heroes {
            let name = "hero_unit_" + row.id
            let p = HeroSpriteProfile.all[name]!
            precondition(p.statureInches > 0 && p.standingBodyFraction > 0)
            precondition(p.groundInsetFraction >= 0 && p.groundInsetFraction < 1)
            near(p.statureInches, row.stature_inches)
            near(p.standingBodyFraction, row.calibration.standing_equivalent_height
                 / row.calibration.normalized_canvas_height)
            near(p.groundInsetFraction, row.calibration.ground_inset_fraction)
            precondition(p.evidence.rawValue == row.evidence)
            // Relative stature must survive both clamping limits and aspect ratios.
            for view in [CGSize.zero, CGSize(width: 320, height: 180),
                         CGSize(width: 661.3333333333, height: 372),
                         CGSize(width: 852, height: 300), CGSize(width: 1024, height: 768),
                         CGSize(width: 2400, height: 1350)] {
                let scale = MapSpriteScale(playArea: CGRect(x: 474, y: 492, width: 1920, height: 1080),
                                           viewSize: view)
                let image = scale.points(MapSpriteSizing.hero(baseAssetName: name))
                let body = image * p.standingBodyFraction
                let gwBody = scale.points(MapSpriteSizing.hero(baseAssetName: "hero_unit_george_washington"))
                    * washington.standingBodyFraction
                near(body / gwBody, p.statureInches / washington.statureInches)
                near(MapSpriteSizing.heroGroundInset(baseAssetName: name, spriteHeight: image),
                     image * p.groundInsetFraction)
            }
            output.append(["id": row.id, "map_height": p.imageHeight.fraction * SpriteHeight.referenceMapHeight,
                           "minimum_image_height_points": p.imageHeight.resolved(playableHeightOnScreen: 340),
                           "image_height_at_372_points": p.imageHeight.resolved(playableHeightOnScreen: 372)])
        }
        precondition(MapSpriteSizing.hero(baseAssetName: "future_unknown_hero") == MapSpriteSizing.hero)
        near(TouchTarget.minimum, 44)
        print(String(data: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
                     encoding: .utf8)!)
    }
}
