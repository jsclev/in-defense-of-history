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
    var body: some View {
        GeometryReader { _ in
            if let store = displayStore,
               let node = CampaignNode.load(db: store.db).first(where: { $0.mapImageName == "level_15_charleston" }),
               let difficulty = try? store.db.difficultyDao.getAll().first {
                let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first!
                let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                    safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                    towerMenuLayout: store.towerMenuLayout, node: node, difficulty: difficulty,
                    hudLayoutConfig: .standard, onExit: {})
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
                let config = try store.db.levelGeoJSONDao.getHeroConfiguration(mapImageName: level.mapImageName)
                let capacity = index < 5 ? 1 : 2
                try require(config.heroCount == capacity, "Wrong capacity for \(level.name)")
                let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas,
                    levelInfoID: level.id, mapImageName: level.mapImageName)
                try require(runner.isReady, "\(level.name): \(runner.status)")
                if scenario == "pair" && index == 14 && viewport != "tablet" {
                    try captureLevel(store: store, canvas: canvas, mapName: level.mapImageName,
                                     name: "level-15-\(viewport)", directory: directory)
                    let debug: [String: Any] = ["heroes": runner.heroes.map { [$0.position.x, $0.position.y] },
                        "obstacles": runner.heroPlacementObstacles(in: canvas).map { [$0.minX, $0.minY, $0.width, $0.height] }]
                    try JSONSerialization.data(withJSONObject: debug, options: .prettyPrinted)
                        .write(to: directory.appendingPathComponent("placement-debug.json"))
                }
                let count = scenario == "solo" ? 1 : capacity
                try require(runner.heroes.count == count && runner.hudHeroes.count == count,
                    "Wrong unit/HUD count for \(level.name) / \(scenario)")
                try require(runner.primaryHero?.id == expectedPrimary, "Wrong primary for \(level.name)")
                try require(runner.secondaryHero?.id == (count == 2 ? chosen.secondary?.id : nil),
                    "Wrong secondary for \(level.name)")
                var placements: [[String: Any]] = []
                let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
                let margin = max(6, canvas.playAreaRect.height * 0.015)
                var frames: [CGRect] = []
                for (unitIndex, role) in [HeroSelection.Role.primary, .secondary].prefix(count).enumerated() {
                    let exit = config.spawns.first { $0.role == role }!
                    let unit = runner.heroes[unitIndex]
                    let footprint = HeroSpriteFootprint(baseAssetName: unit.baseAssetName,
                        aspectRatio: unit.imageAspectRatio, playableHeight: canvas.playAreaRect.height)
                    let frame = footprint.frame(at: projection.viewPoint(unit.position))
                    let padded = frame.insetBy(dx: -margin + 0.00001, dy: -margin + 0.00001)
                    try require(CGPath(rect: padded, transform: nil).subtracting(canvas.runtimePlayArea).isEmpty,
                                "\(level.name) / \(role): sprite crosses playable bounds")
                    try require(!runner.heroPlacementObstacles(in: canvas).contains { $0.intersects(padded) },
                                "\(level.name) / \(role): sprite is hidden behind HUD")
                    try require(runner.heroPlacementOcclusion?.rectangles(in: padded, canvas: canvas).isEmpty == true,
                                "\(level.name) / \(role): sprite is hidden behind foliage")
                    try require(!frames.contains { $0.intersects(padded) }, "Overlapping heroes")
                    try require(runner.heroStartingPlacements[unitIndex].exit == exit, "Lost ranking/exit association")
                    for point in try store.db.levelGeoJSONDao.getExitPoints(mapImageName: level.mapImageName) {
                        let target = projection.viewPoint(CGPoint(x: point.position.x, y: point.position.y))
                        let gap = hypot(max(frame.minX - target.x, 0, target.x - frame.maxX),
                                        max(frame.minY - target.y, 0, target.y - frame.maxY))
                        try require(gap >= margin - 0.00001,
                                    "Sprite covers an exit")
                    }
                    if index == 14 {
                        let foot = projection.viewPoint(unit.position)
                        let mouth = projection.viewPoint(CGPoint(x: exit.position.x, y: exit.position.y))
                        let section = runner.heroStartingPlacements[unitIndex].pathCrossSection
                        try require(section != nil, "Charleston did not load the polygon boundary")
                        if let section {
                            let position = Point(unit.position.x, unit.position.y)
                            try require(position.distance(to: section.center) < 0.000001,
                                        "Hero is not centered between the road edges")
                            try require(abs(position.distance(to: section.firstEdge) - position.distance(to: section.secondEdge)) < 0.000001,
                                        "Unequal road-edge distances")
                        }
                        let outside = hypot(max(canvas.playAreaRect.minX - mouth.x, 0, mouth.x - canvas.playAreaRect.maxX),
                                            max(canvas.playAreaRect.minY - mouth.y, 0, mouth.y - canvas.playAreaRect.maxY))
                        try require(hypot(foot.x - mouth.x, foot.y - mouth.y) < outside + footprint.size.height * 3,
                                    "Charleston hero drifted into mid-map")
                    }
                    frames.append(frame)
                    placements.append(["role": role.rawValue, "hero": runner.hudHeroes[unitIndex].shortName,
                        "exitID": exit.exitID, "position": [unit.position.x, unit.position.y],
                        "exitPosition": [exit.position.x, exit.position.y],
                        "pathCrossSection": runner.heroStartingPlacements[unitIndex].pathCrossSection.map {
                            [[$0.firstEdge.x, $0.firstEdge.y], [$0.secondEdge.x, $0.secondEdge.y], [$0.direction.x, $0.direction.y]]
                        } ?? [],
                        "spriteFrame": [frame.minX, frame.minY, frame.width, frame.height],
                        "edgeGaps": [frame.minX - canvas.playAreaRect.minX, canvas.playAreaRect.maxX - frame.maxX,
                                     frame.minY - canvas.playAreaRect.minY, canvas.playAreaRect.maxY - frame.maxY]])
                }
                let respawns = runner.probeHeroRespawns()
                try require(respawns == runner.heroStartingPlacements.map { CGPoint(x: $0.position.x, y: $0.position.y) },
                            "Hero respawn does not use safe starting positions")
                rows.append(["scenario": scenario, "viewport": viewport, "level": index + 1, "name": level.name,
                    "capacity": capacity, "heroes": placements, "ready": runner.isReady, "margin": margin])
                try Data("Completed \(rows.count) loads".utf8)
                    .write(to: directory.appendingPathComponent("progress.txt"), options: .atomic)
                if scenario == "pair" && index == 6 && viewport != "tablet" {
                    try captureLevel(store: store, canvas: canvas, mapName: level.mapImageName,
                                     name: "level-\(index + 1)-\(viewport)", directory: directory)
                }
                if viewport == "minimum" {
                    let wider = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                        physicalRect: viewports[1].1, safeInsetsRect: viewports[1].2)
                    runner.updateRuntimeCanvas(wider)
                    for (unit, placement) in zip(runner.heroes, runner.heroStartingPlacements) {
                        try require(unit.position == CGPoint(x: placement.position.x, y: placement.position.y),
                                    "Stationary hero did not follow resized starting position")
                        let padded = placement.spriteFrame.insetBy(dx: -6 + 0.00001, dy: -6 + 0.00001)
                        try require(CGPath(rect: padded, transform: nil).subtracting(wider.runtimePlayArea).isEmpty,
                                    "Resized sprite crosses play area")
                    }
                }
                await Task.yield()
            }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: ["passed": true, "loads": rows.count,
            "checks": rows], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("hero-exits.json"), options: .atomic)
    } catch {
        let data = try! JSONSerialization.data(withJSONObject: ["passed": false,
            "error": String(describing: error), "checks": rows], options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: directory.appendingPathComponent("hero-exits.json"), options: .atomic)
    }
}

@MainActor private func captureLevel(store: Store, canvas: RuntimeCanvas, mapName: String,
                                    name: String, directory: URL) throws {
    let node = CampaignNode.load(db: store.db).first { $0.mapImageName == mapName }!
    let difficulty = try store.db.difficultyDao.getAll()[0]
    let view = LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
        towerMenuLayout: store.towerMenuLayout, node: node, difficulty: difficulty,
        hudLayoutConfig: .standard, onExit: {})
        .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height)
    for scale in [CGFloat(1), 3] {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let png = renderer.uiImage?.pngData() else { throw ProbeFailure(description: "No runtime image") }
        try png.write(to: directory.appendingPathComponent("\(name)@\(Int(scale))x.png"))
    }
}
