import Foundation

@main struct GameReference {
    struct Pair: Decodable { let a: Point; let b: Point }
    struct Navigation: Decodable { let file: String; let width: Double; let points: [Point]; let pairs: [Pair] }
    struct Operation: Decodable { let kind: String; let tick: Int64; let point: Point; let slot: Int }
    struct Input: Decodable { let navigation: [Navigation]; let waves: [Wave]; let reinforcement: ReinforcementConfig; let operations: [Operation] }
    static func main() throws {
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let nav: [[String: Any]] = try input.navigation.map { probe in
            let area = try HeroMovementArea(geoJSON: Data(contentsOf: URL(fileURLWithPath: probe.file)), defaultPathWidth: probe.width)
            return ["contains": probe.points.map { area.contains($0) }, "segments": probe.pairs.map { area.containsSegment(from: $0.a, to: $0.b) },
                "routes": probe.pairs.map { pair -> Any in
                    area.route(from: pair.a, to: pair.b).map { $0.map { ["x": $0.x, "y": $0.y] } } ?? NSNull()
                }]
        }
        var waves = try WaveStartSchedule(waves: input.waves)
        var reinforcements = ReinforcementSchedule(config: input.reinforcement)
        var selection = CallWaveButtonSelection()
        let events: [[String: Any]] = input.operations.map { operation in
            var event: [String: Any] = [:]
            switch operation.kind {
            case "waveTap":
                if waves.state(at: operation.tick).canCall && selection.tap(operation.point, for: waves.nextWaveIndex + 1),
                   let start = waves.startNextWave(at: operation.tick, manually: true) {
                    event["wave"] = start.index; event["bonus"] = start.moneyBonus
                }
            case "auto":
                if let start = waves.startNextWave(at: operation.tick, manually: false) { event["wave"] = start.index; event["bonus"] = start.moneyBonus }
            case "deploy": event["deployed"] = reinforcements.deploy(slot: operation.slot, at: operation.tick)
            default: break
            }
            event["expired"] = reinforcements.expire(at: operation.tick)
            let cooldown = reinforcements.cooldown(at: operation.tick)
            event["fraction"] = cooldown.remainingFraction; event["seconds"] = cooldown.displaySeconds
            event["next"] = waves.nextWaveIndex; event["canCall"] = waves.state(at: operation.tick).canCall
            switch waves.state(at: operation.tick) {
            case .finished: event["kind"] = "finished"
            case .manualFirstWave: event["kind"] = "manual"
            case .hidden: event["kind"] = "hidden"
            case .countingDown(let seconds): event["kind"] = "countdown"; event["countdown"] = seconds
            case .due: event["kind"] = "due"
            }
            return event
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: ["navigation": nav, "events": events]))
    }
}
