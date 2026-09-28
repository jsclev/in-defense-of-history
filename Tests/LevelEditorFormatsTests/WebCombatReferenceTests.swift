import XCTest
@testable import LevelEditorFormats

/// The web unit suite supplies authored SQLite values and compares these results
/// with TypeScript. Compile and execute through the ordinary SwiftPM test target.
final class WebCombatReferenceTests: XCTestCase {
    struct Probe: Decodable {
        let origin: Point, target: Point, end: Point
        let heading: Double, rate: Double, seconds: Double, radius: Double, vertical: Double
        let along: Double, travel: Double, loss: Double, discipline: Double, blocked: Bool
    }
    struct Input: Decodable {
        let tuning: TowerLevel
        let response: EnemyMoraleResponse
        let probes: [Probe]
        let path: [Point]
    }
    func testExport() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let source = environment["LIBERTY_LINE_WEB_COMBAT_INPUT"],
              let destination = environment["LIBERTY_LINE_WEB_COMBAT_OUTPUT"] else {
            throw XCTSkip("Invoked by LibertyLineWeb/tests/combat-math.test.ts with authored content")
        }
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: source)))
        let rules = input.tuning.combatRules, path = Path(points: input.path)
        var morale = EnemyMorale(rules: rules)
        let strike = ArtilleryMoraleStrike(tuning: input.tuning)
        var result: [[String: Any]] = []
        for p in input.probes {
            let origin = CGPoint(x: p.origin.x, y: p.origin.y), target = CGPoint(x: p.target.x, y: p.target.y)
            let end = CGPoint(x: p.end.x, y: p.end.y)
            let range = TowerAttackRange(p.radius, verticalFraction: p.vertical)
            let clamped = range.clamped(target, from: origin)
            var aim = ArtilleryAim(heading: p.heading, firingTolerance: rules.firingTolerance)
            let aligned = aim.track(from: origin, to: target, radiansPerSecond: p.rate, deltaTime: p.seconds)
            var charge = DemolitionCharge(preparationSeconds: 1)
            charge.place(at: origin)
            let exits = charge.willEnemyExitBlast(on: path, from: p.along, advancingBy: p.travel,
                radius: p.radius, targetOffset: CGPoint(x: rules.enemyBodyOffsetX, y: rules.enemyBodyOffsetY))
            let applied = morale.apply(loss: p.loss, direction: target.x - origin.x)
            let travel = morale.advance(seconds: p.seconds, baseSpeed: 80, response: input.response, blocked: p.blocked)
            let contacts = GrapeshotFlight.hitFraction(from: origin, to: end, target: target, radius: rules.grapeshotHitRadius)
            result.append(["heading": aim.heading, "aligned": aligned, "clamped": ["x": clamped.x, "y": clamped.y],
                "range": range.travelDistance(heading: p.heading), "hit": contacts as Any? ?? NSNull(), "exits": exits,
                "loss": strike.loss(distance: p.travel, discipline: p.discipline), "applied": applied,
                "value": morale.value, "displayed": morale.displayedValue, "fraction": morale.remainingFraction,
                "displayedFraction": morale.displayedFraction, "visible": morale.isVisible, "direction": morale.flinchDirection,
                "travel": travel, "attack": input.response.damageMultiplier(morale: morale.value, maximum: rules.moraleMax)])
        }
        try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]).write(to: URL(fileURLWithPath: destination))
    }
}
