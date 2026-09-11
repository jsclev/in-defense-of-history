// Loads the real runner in a separate physical-device app; no production save is used.
import SwiftUI
import SQLite3

@main struct HeroExitRuntimeProbe: App {
    var body: some Scene {
        WindowGroup { HeroExitProbeScreen() }
    }
}

private struct HeroExitProbeScreen: View {
    @State private var displayStore: Store?
    @State private var minimum = false
    var body: some View {
        GeometryReader { _ in
            if let store = displayStore,
               let node = CampaignNode.load(db: store.db).first(where: { $0.mapImageName == "level_15_charleston" }),
               let difficulty = try? store.db.difficultyDao.getAll().first {
                let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first!
                let minimumRect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
                let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                    physicalRect: minimum ? minimumRect : window.bounds,
                    safeInsetsRect: minimum ? minimumRect : window.bounds.inset(by: window.safeAreaInsets))
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                    towerMenuLayout: store.towerMenuLayout, node: node, difficulty: difficulty,
                    hudLayoutConfig: .standard, onExit: {})
                    .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height)
                    .task {
                        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        for small in [false, true] {
                            minimum = small
                            try? await Task.sleep(for: .seconds(2))
                            let format = UIGraphicsImageRendererFormat()
                            format.scale = 1
                            let image = UIGraphicsImageRenderer(bounds: small ? minimumRect : window.bounds,
                                                               format: format).image { _ in
                                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                            }
                            try? image.pngData()?.write(to: directory.appendingPathComponent(
                                small ? "level-15-minimum.png" : "level-15-device.png"))
                        }
                        let args = CommandLine.arguments
                        let runID = args.firstIndex(of: "--probe-run-id").map { args[$0 + 1] } ?? "manual"
                        try? Data(runID.utf8).write(to: directory.appendingPathComponent("captures-ready.txt"))
                    }
            } else {
                Text("Checking hero exits on this iPhone").task {
                    await checkHeroExits()
                    displayStore = Store()
                }
            }
        }.ignoresSafeArea()
    }
}

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor private func checkHeroExits() async {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var rows: [[String: Any]] = []
    var waveChecks: [[String: Any]] = []
    let arguments = CommandLine.arguments
    let runID = arguments.firstIndex(of: "--probe-run-id").flatMap {
        arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
    } ?? "manual"
    func require(_ value: Bool, _ message: String) throws {
        if !value { throw ProbeFailure(description: message) }
    }
    do {
        let store = Store()
        let levels = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
        try require(levels.count == 15, "Expected 15 main campaign levels")
        let roster = try store.db.heroDao.getAll()
        let washington = roster.first { $0.shortName == "George Washington" }!
        let knox = roster.first { $0.shortName == "Henry Knox" }!
        let selectionStore = HeroSelectionStore(dao: store.db.heroDao)
        var viewports: [(String, CGRect, CGRect)] = [
            ("minimum", CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340),
             CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)),
            ("phone", CGRect(x: 0, y: 0, width: 874, height: 402),
             CGRect(x: 62, y: 0, width: 750, height: 382)),
            ("tablet", CGRect(x: 0, y: 0, width: 1376, height: 1032),
             CGRect(x: 0, y: 24, width: 1376, height: 984))]

        if let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first {
            viewports.append(("device", window.bounds, window.bounds.inset(by: window.safeAreaInsets)))
        }
        for scenario in ["pair", "solo", "ranking-changed"] {
            if scenario == "ranking-changed" {
                // Only this disposable app's copied database is changed.
                var connection: OpaquePointer?
                let path = directory.appendingPathComponent("in_defense_of_history.sqlite").path
                try require(sqlite3_open(path, &connection) == SQLITE_OK, "Open probe database")
                defer { sqlite3_close(connection) }
                let sql = "UPDATE hero SET ranking = 100 WHERE id = '\(knox.id.uuidString.lowercased())' COLLATE NOCASE"
                try require(sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK, "Update probe ranking")
            }
            let choices = scenario == "solo" ? [knox] : [knox, washington]
            let chosen = try selectionStore.save(HeroSelection(heroes: choices))
            let expectedPrimary = scenario == "pair" ? washington.id : knox.id
            try require(chosen.primary.id == expectedPrimary, "Ranking did not resolve primary in \(scenario)")
            for (viewport, physical, safe) in viewports {
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: physical, safeInsetsRect: safe)
            // Verify and render the reported regression first.
            let orderedLevels = levels.enumerated().sorted {
                ($0.offset == 14 ? -1 : $0.offset) < ($1.offset == 14 ? -1 : $1.offset)
            }
            for (index, level) in orderedLevels {
                if CommandLine.arguments.contains("--level-15-only") && index != 14 { continue }
                if index != 14 && viewport != "minimum" { continue }
                let config = try store.db.levelGeoJSONDao.getHeroConfiguration(mapImageName: level.mapImageName)
                let capacity = index < 5 ? 1 : 2
                try require(config.heroCount == capacity, "Wrong capacity for \(level.name)")
                let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas,
                    levelInfoID: level.id, mapImageName: level.mapImageName)
                try require(runner.isReady, "\(level.name): \(runner.status)")
                let count = scenario == "solo" ? 1 : capacity
                try require(runner.heroes.count == count && runner.hudHeroes.count == count,
                    "Wrong unit/HUD count for \(level.name) / \(scenario)")
                try require(runner.primaryHero?.id == expectedPrimary, "Wrong primary for \(level.name)")
                try require(runner.secondaryHero?.id == (count == 2 ? chosen.secondary?.id : nil),
                    "Wrong secondary for \(level.name)")
                var placements: [[String: Any]] = []
                for (unitIndex, role) in [HeroSelection.Role.primary, .secondary].prefix(count).enumerated() {
                    let exit = config.spawns.first { $0.role == role }!
                    let unit = runner.heroes[unitIndex]
                    if index == 14 && CommandLine.arguments.contains("--custom-starts") {
                        let authored = role == .primary ? Point(1520.25, 1100.75) : Point(1700.5, 900.125)
                        try require(exit.position == authored, "Custom GeoJSON coordinates were not loaded")
                    }
                    try require(unit.position == CGPoint(x: exit.position.x, y: exit.position.y),
                                "\(level.name) / \(role): starting position differs from GeoJSON")
                    placements.append(["role": role.rawValue, "hero": runner.hudHeroes[unitIndex].shortName,
                        "featureID": exit.featureID, "position": [unit.position.x, unit.position.y],
                        "authoredPosition": [exit.position.x, exit.position.y]])
                }
                let expected = runner.heroes.map(\.position)
                try require(runner.probeHeroRespawns() == expected, "Respawn moved a hero away from its authored point")
                let resized = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                    physicalRect: viewports[1].1, safeInsetsRect: viewports[1].2)
                runner.updateRuntimeCanvas(resized)
                try require(runner.heroes.map(\.position) == expected, "Resize moved a hero away from its authored point")
                try require(runner.probeHeroRespawns() == expected, "Resize changed a future respawn position")
                rows.append(["scenario": scenario, "viewport": viewport, "level": index + 1, "name": level.name,
                    "capacity": capacity, "heroes": placements, "ready": runner.isReady])
                try Data("Completed \(rows.count) loads".utf8)
                    .write(to: directory.appendingPathComponent("progress.txt"), options: .atomic)
                if index == 14 && scenario == "pair" && viewport == "minimum" {
                    waveChecks = try runner.probeCharlestonWaveStarts()
                }
                await Task.yield()
            }
            }
        }
        _ = try selectionStore.save(HeroSelection(heroes: [washington, knox]))
        let data = try JSONSerialization.data(withJSONObject: ["passed": true, "runID": runID, "loads": rows.count,
            "checks": rows, "waveChecks": waveChecks], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("hero-exits.json"), options: .atomic)
    } catch {
        let data = try! JSONSerialization.data(withJSONObject: ["passed": false, "runID": runID,
            "error": String(describing: error), "checks": rows, "waveChecks": waveChecks], options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: directory.appendingPathComponent("hero-exits.json"), options: .atomic)
    }
}
