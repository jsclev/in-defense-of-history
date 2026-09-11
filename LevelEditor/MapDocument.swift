import SwiftUI
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let tdmap = UTType(exportedAs: "com.zippyzen.td.map", conformingTo: .json)
}

nonisolated struct MapDraft: Codable, Equatable, Sendable {
    nonisolated struct Road: Codable, Equatable, Sendable {
        var name: String
        var points: [Point]
        /// Cutouts in the rendered band; navigation waypoints stay editable.
        var erasedArea: LevelGeoJSON.Geometry?

        init(name: String, points: [Point]) {
            self.name = name
            self.points = points
        }

        func outerEdge(halfWidth: Double) -> [Point] {
            BrushGeometry.outerEdge(points: points, halfWidth: halfWidth)
        }
    }

    nonisolated struct SpawnLine: Codable, Equatable, Sendable {
        var foe: String
        var count: Int
        var every: Double
        var delay: Double
        var road: Int
    }

    nonisolated struct Wave: Codable, Equatable, Sendable {
        var breather: Double
        var lines: [SpawnLine]
        var callButtonDelay: Double? = nil
        var autoStartCountdown: Double? = nil
        var earlyCallBonus: Int? = nil
    }

    nonisolated struct BuildStep: Codable, Equatable, Sendable {
        var at: Double
        var kind: String
        var emplacement: String?
        var slot: Int
    }

    static let canvasSpace = "canonical2868x2064"

    var name: String
    var startingGold: Int
    var lives: Int
    var roads: [Road]
    /// Directed enemy marches; kept separate from the painted road footprint.
    var enemyRoutes: [EnemyRoute] = []
    var slots: [Point]
    var entrances: [Point]
    var exits: [Point]
    var waves: [Wave]
    var intendedSolution: [BuildStep]
    var backgroundImagePath: String?
    var backgroundOpacity: Double
    var overlayImagePath: String?
    var guideImagePath: String?
    var guideOpacity: Double = 0.5
    var coordinateSpace: String = Self.canvasSpace
    var roadPaint: [PaintStroke] = []
    /// A GeoJSON import is one flattened layer; native roads remain separate.
    /// An empty MultiPolygon represents an imported layer erased completely.
    var flattenedPath: LevelGeoJSON.Geometry?
    var backgroundImageData: Data?
    var overlayImageData: Data?
    var guideImageData: Data?
    var hiddenLayers: [String] = []
    /// Authored centers and the incoming routes that make each button visible.
    var callWaveButtons: [CallWaveButtonPosition] = []
    var heroCount: Int = 0
    var primaryHeroPosition: Point?
    var secondaryHeroPosition: Point?

    func hasHero(_ role: HeroSelection.Role) -> Bool {
        heroCount >= (role == .primary ? 1 : 2)
    }

    func heroPosition(_ role: HeroSelection.Role) -> Point? {
        role == .primary ? primaryHeroPosition : secondaryHeroPosition
    }

    func heroMarkerPosition(_ role: HeroSelection.Role) -> Point? {
        hasHero(role) ? heroPosition(role) : nil
    }

    mutating func placeHero(_ role: HeroSelection.Role, at position: Point) {
        heroCount = max(heroCount, role == .primary ? 1 : 2)
        if role == .primary { primaryHeroPosition = position }
        else { secondaryHeroPosition = position }
    }

    mutating func removeHeroStart(_ role: HeroSelection.Role) {
        if role == .primary { primaryHeroPosition = nil }
        else { secondaryHeroPosition = nil }
    }

    mutating func removeExit(at index: Int) {
        guard exits.indices.contains(index) else { return }
        exits.remove(at: index)
    }

    nonisolated struct PaintStroke: Codable, Equatable, Sendable {
        var points: [Point]
        var width: Double
        var erases: Bool
        var erasedArea: LevelGeoJSON.Geometry?
    }

    static let starter = MapDraft(
        name: "Untitled Map",
        startingGold: 220,
        lives: 20,
        roads: [],
        slots: [],
        entrances: [],
        exits: [],
        waves: [Wave(breather: 10, lines: [
            SpawnLine(foe: Foe.loyalistMilitia.rawValue, count: 6, every: 2.2, delay: 0, road: 0),
        ])],
        intendedSolution: [],
        backgroundImagePath: nil,
        backgroundOpacity: 0.35,
        overlayImagePath: nil
    )

    var isPlayable: Bool {
        roads.contains { $0.points.count >= 2 } && !waves.isEmpty
    }

    /// Subtracts the circular brush from every existing visible path surface.
    /// Cutouts belong to their road/paint, so later painting can fill them back
    /// in. Erasing the footprint does not delete or renumber navigation routes.
    mutating func applyErase(_ eraser: PaintStroke, mapGeometry: MapGeometry) {
        guard !eraser.points.isEmpty, eraser.width.isFinite, eraser.width > 0,
              eraser.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return }
        let strokeArea = BrushGeometry.strokeArea(points: eraser.points, width: eraser.width)
        guard let brushGeometry = try? PathFlattening.geometry(from: strokeArea) else { return }
        // Commit the same polygon we persist. Re-subtracting the original
        // curve from its flattened cutout would change rounding on every dab.
        let brush = PathFlattening.area(for: brushGeometry)
        func mask(addingTo previous: LevelGeoJSON.Geometry?) -> LevelGeoJSON.Geometry? {
            guard let previous else { return brushGeometry }
            if previous == brushGeometry { return previous }
            let existing = PathFlattening.area(for: previous)
            guard !brush.subtracting(existing).isEmpty else { return previous }
            return try? PathFlattening.geometry(from: existing.union(brush))
        }
        if let base = flattenedPath {
            let area = PathFlattening.area(for: base)
            if !area.intersection(brush).isEmpty {
                // Keep the imported-layer identity even when completely erased,
                // so its wave route indices survive painting a replacement.
                let remaining = area.subtracting(brush)
                flattenedPath = remaining.isEmpty ? .multiPolygon([])
                    : (try? PathFlattening.geometry(from: remaining)) ?? base
            }
        }
        for i in roads.indices {
            let area = BrushGeometry.strokeArea(points: roads[i].points,
                width: mapGeometry.roadHalfWidth * 2, erasedArea: roads[i].erasedArea)
            guard !area.intersection(brush).isEmpty else { continue }
            roads[i].erasedArea = mask(addingTo: roads[i].erasedArea) ?? roads[i].erasedArea
        }
        for i in roadPaint.indices where !roadPaint[i].erases {
            let stroke = roadPaint[i]
            let area = BrushGeometry.strokeArea(points: stroke.points, width: stroke.width,
                                                erasedArea: stroke.erasedArea)
            guard !area.intersection(brush).isEmpty else { continue }
            roadPaint[i].erasedArea = mask(addingTo: stroke.erasedArea) ?? stroke.erasedArea
        }
    }

    /// A draft authored before the eraser merged down stored its eraser strokes
    /// as a layer. Replay them in author order and drop them, so no draft in
    /// memory ever carries one.
    mutating func bakeStoredErasures(mapGeometry: MapGeometry) {
        guard roadPaint.contains(where: \.erases) else { return }
        let strokes = roadPaint
        roadPaint = []
        for stroke in strokes {
            if stroke.erases {
                applyErase(stroke, mapGeometry: mapGeometry)
            } else {
                roadPaint.append(stroke)
            }
        }
    }

    /// Deleted roads can leave gaps, so allocating by count would collide.
    static func freeRoadName(taken: Set<String>) -> String {
        var n = taken.count + 1
        while taken.contains("Road \(n)") { n += 1 }
        return "Road \(n)"
    }
}

extension MapDraft {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Map"
        startingGold = try c.decodeIfPresent(Int.self, forKey: .startingGold) ?? 220
        lives = try c.decodeIfPresent(Int.self, forKey: .lives) ?? 20
        roads = try c.decodeIfPresent([Road].self, forKey: .roads) ?? []
        enemyRoutes = try c.decodeIfPresent([EnemyRoute].self, forKey: .enemyRoutes) ?? []
        slots = try c.decodeIfPresent([Point].self, forKey: .slots) ?? []
        entrances = try c.decodeIfPresent([Point].self, forKey: .entrances) ?? []
        callWaveButtons = try c.decodeIfPresent([CallWaveButtonPosition].self, forKey: .callWaveButtons) ?? []
        exits = try c.decodeIfPresent([Point].self, forKey: .exits) ?? []
        heroCount = try c.decodeIfPresent(Int.self, forKey: .heroCount) ?? 0
        primaryHeroPosition = try c.decodeIfPresent(Point.self, forKey: .primaryHeroPosition)
        secondaryHeroPosition = try c.decodeIfPresent(Point.self, forKey: .secondaryHeroPosition)
        waves = try c.decodeIfPresent([Wave].self, forKey: .waves) ?? []
        intendedSolution = try c.decodeIfPresent([BuildStep].self, forKey: .intendedSolution) ?? []
        backgroundImagePath = try c.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.35
        overlayImagePath = try c.decodeIfPresent(String.self, forKey: .overlayImagePath)
        guideImagePath = try c.decodeIfPresent(String.self, forKey: .guideImagePath)
        guideOpacity = try c.decodeIfPresent(Double.self, forKey: .guideOpacity) ?? 0.5
        coordinateSpace = try c.decodeIfPresent(String.self, forKey: .coordinateSpace) ?? "design1600x900"
        roadPaint = try c.decodeIfPresent([PaintStroke].self, forKey: .roadPaint) ?? []
        flattenedPath = try c.decodeIfPresent(LevelGeoJSON.Geometry.self, forKey: .flattenedPath)
        backgroundImageData = try c.decodeIfPresent(Data.self, forKey: .backgroundImageData)
        overlayImageData = try c.decodeIfPresent(Data.self, forKey: .overlayImageData)
        guideImageData = try c.decodeIfPresent(Data.self, forKey: .guideImageData)
        hiddenLayers = try c.decodeIfPresent([String].self, forKey: .hiddenLayers) ?? []
        enum LegacyKeys: String, CodingKey { case primaryHeroExitIndex, secondaryHeroExitIndex }
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        func oldPosition(_ key: LegacyKeys) throws -> Point? {
            guard let index = try legacy.decodeIfPresent(Int.self, forKey: key), exits.indices.contains(index) else { return nil }
            return exits[index]
        }
        if primaryHeroPosition == nil { primaryHeroPosition = try oldPosition(.primaryHeroExitIndex) }
        if secondaryHeroPosition == nil { secondaryHeroPosition = try oldPosition(.secondaryHeroExitIndex) }
    }

    /// Brings a freshly opened draft into the canonical space: legacy
    /// coordinate spaces are converted and stored eraser strokes baked. Both
    /// need the canvas, which a Decodable init cannot receive, so this runs
    /// right after open instead of inside decoding.
    mutating func normalize(mapGeometry: MapGeometry) {
        if coordinateSpace != Self.canvasSpace {
            let vc = mapGeometry.virtualCanvas
            let upgrade: (Point) -> Point
            if coordinateSpace == "design1600x900" {
                let legacyDesignWidth = 1600.0
                let s = vc.playAreaRect.width / legacyDesignWidth
                upgrade = { p in
                    Point(p.x * s + vc.playAreaRect.minX,
                          vc.flipY(p.y * s + vc.playAreaRect.minY))
                }
            } else {
                upgrade = { Point($0.x, vc.flipY($0.y)) }
            }
            for r in roads.indices {
                roads[r].points = roads[r].points.map(upgrade)
            }
            for r in enemyRoutes.indices { enemyRoutes[r].points = enemyRoutes[r].points.map(upgrade) }
            slots = slots.map(upgrade)
            entrances = entrances.map(upgrade)
            for i in callWaveButtons.indices {
                callWaveButtons[i].position = upgrade(callWaveButtons[i].position)
            }
            exits = exits.map(upgrade)
            primaryHeroPosition = primaryHeroPosition.map(upgrade)
            secondaryHeroPosition = secondaryHeroPosition.map(upgrade)
            coordinateSpace = Self.canvasSpace
        }
        bakeStoredErasures(mapGeometry: mapGeometry)
    }

    init(blueprint bp: LevelBlueprint) {
        self.init(
            name: bp.name,
            startingGold: bp.startingGold,
            lives: bp.lives,
            roads: bp.roads.map { Road(name: $0.name, points: $0.waypoints) },
            slots: bp.slots,
            entrances: [],
            exits: [],
            waves: bp.waves.map { w in
                Wave(breather: w.breather, lines: w.lines.map {
                    SpawnLine(foe: $0.foe.rawValue, count: $0.count, every: $0.every,
                              delay: $0.delay, road: $0.road)
                })
            },
            intendedSolution: bp.intendedSolution.map { s in
                switch s.order {
                case let .place(e, slot):
                    BuildStep(at: s.at, kind: "place", emplacement: e.rawValue, slot: slot)
                case let .upgrade(slot):
                    BuildStep(at: s.at, kind: "upgrade", emplacement: nil, slot: slot)
                }
            },
            backgroundImagePath: nil,
            backgroundOpacity: 0.35,
            overlayImagePath: nil
        )
    }

    func makeBlueprint(virtualCanvas: VirtualCanvas) -> LevelBlueprint {
        let routes = roads.filter { $0.points.count >= 2 }
        return LevelBlueprint(
            virtualCanvas: virtualCanvas,
            name: name,
            startingGold: startingGold,
            lives: lives,
            roads: routes.map { LevelBlueprint.Road($0.name, $0.points) },
            slots: slots,
            waves: waves.map { w in
                LevelBlueprint.WaveSketch(breather: w.breather, lines: w.lines.map { l in
                    LevelBlueprint.SpawnLine(
                        Foe(rawValue: l.foe) ?? .loyalistMilitia,
                        count: l.count, every: l.every, delay: l.delay,
                        road: min(l.road, max(0, routes.count - 1))
                    )
                })
            },
            intendedSolution: intendedSolution.compactMap { s in
                guard slots.indices.contains(s.slot) else { return nil }
                if s.kind == "place" {
                    let e = s.emplacement.flatMap(Emplacement.init(rawValue:)) ?? .minutemanPost
                    return LevelBlueprint.BuildStep(at: s.at, .place(e, slot: s.slot))
                }
                return LevelBlueprint.BuildStep(at: s.at, .upgrade(slot: s.slot))
            }
        )
    }
}

final class MapDocument: ReferenceFileDocument {
    typealias Snapshot = NativeMapFile

    @Published var draft: MapDraft
    var canvas: VirtualCanvas?
    var sourceFolder: URL?

    // Open/Save work only with the native document. GeoJSON is explicitly
    // imported or exported so autosave can never overwrite an export.
    static var readableContentTypes: [UTType] { [.tdmap] }
    static var writableContentTypes: [UTType] { [.tdmap] }

    init(canvas: VirtualCanvas) {
        draft = .starter
        self.canvas = canvas
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if root?["format"] != nil || root?["version"] != nil || root?["draft"] != nil {
            let file = try NativeMapFile.read(data)
            draft = file.draft
            canvas = file.canvas
        } else {
            guard root?["roads"] != nil else {
                throw CocoaError(.fileReadCorruptFile)
            }
            // Existing unversioned .tdmap files remain readable.
            draft = try JSONDecoder().decode(MapDraft.self, from: data)
        }
    }

    func snapshot(contentType: UTType) throws -> NativeMapFile {
        guard let canvas else {
            throw LevelGeoJSON.ValidationError(message: "The document's canvas has not loaded yet.")
        }
        var saved = draft
        func embedded(_ data: Data?, path: String?) throws -> Data? {
            guard let path else { return nil }
            if let data { return data }
            let original = URL(fileURLWithPath: path)
            let sibling = sourceFolder?.appendingPathComponent(original.lastPathComponent)
            let url = FileManager.default.fileExists(atPath: original.path) ? original : sibling ?? original
            guard let bytes = PlatformImageLoader.freshRead(url) else {
                throw LevelGeoJSON.ValidationError(message: "Cannot embed \(original.lastPathComponent). Locate the image or remove its layer before saving.")
            }
            return bytes
        }
        saved.backgroundImageData = try embedded(saved.backgroundImageData, path: saved.backgroundImagePath)
        saved.overlayImageData = try embedded(saved.overlayImageData, path: saved.overlayImagePath)
        saved.guideImageData = try embedded(saved.guideImageData, path: saved.guideImagePath)
        return NativeMapFile(draft: saved, canvas: canvas)
    }

    func fileWrapper(snapshot: NativeMapFile, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try snapshot.data())
    }

    @MainActor
    func edit(_ undoManager: UndoManager?, _ apply: (inout MapDraft) -> Void) {
        let before = draft
        apply(&draft)
        if draft != before {
            registerUndo(from: before, undoManager)
        }
    }

    @MainActor
    func registerUndo(from before: MapDraft, _ undoManager: UndoManager?) {
        undoManager?.registerUndo(withTarget: self) { doc in
            MainActor.assumeIsolated {
                let now = doc.draft
                doc.draft = before
                doc.registerUndo(from: now, undoManager)
            }
        }
    }

    @MainActor
    func binding<V: Equatable>(_ keyPath: WritableKeyPath<MapDraft, V>,
                               _ undoManager: UndoManager?) -> Binding<V> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { newValue in self.edit(undoManager) { $0[keyPath: keyPath] = newValue } }
        )
    }

    /// THE one way a slot is added, whatever the input - canvas tap, pencil,
    /// or the panel button. Returns the new slot's index.
    @MainActor
    @discardableResult
    func addSlot(at p: Point, _ undoManager: UndoManager?) -> Int {
        edit(undoManager) { $0.slots.append(p) }
        return draft.slots.count - 1
    }

    @MainActor
    func deleteSlot(_ i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.slots.indices.contains(i) else { return }
            d.slots.remove(at: i)
            d.intendedSolution.removeAll { $0.slot == i }
            for k in d.intendedSolution.indices where d.intendedSolution[k].slot > i {
                d.intendedSolution[k].slot -= 1
            }
        }
    }

    @MainActor
    func deleteRoad(_ r: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.roads.indices.contains(r) else { return }
            d.roads.remove(at: r)
            for w in d.waves.indices {
                for l in d.waves[w].lines.indices {
                    if d.waves[w].lines[l].road == r { d.waves[w].lines[l].road = 0 }
                    else if d.waves[w].lines[l].road > r { d.waves[w].lines[l].road -= 1 }
                }
            }
        }
    }

    @MainActor
    func deleteCallWaveButton(_ i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.callWaveButtons.indices.contains(i) else { return }
            d.callWaveButtons.remove(at: i)
        }
    }

    @MainActor
    func deleteEntrance(_ i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.entrances.indices.contains(i) else { return }
            d.entrances.remove(at: i)
        }
    }

    @MainActor
    func deleteExit(_ i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            d.removeExit(at: i)
        }
    }

    @MainActor
    func deleteWaypoint(road r: Int, point i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.roads.indices.contains(r), d.roads[r].points.indices.contains(i) else { return }
            d.roads[r].points.remove(at: i)
        }
    }

    @MainActor
    func addPaintedRoad(points: [Point], _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            d.roads.append(.init(name: MapDraft.freeRoadName(taken: Set(d.roads.map(\.name))),
                                 points: points))
        }
    }


    /// Merge a road onto the road below it in the list.
    ///
    /// The run of this road's waypoints that lies inside the lower road's lane
    /// (a branch joining a trunk) is replaced by the lower road's OWN
    /// waypoints from the junction onward, so the shared stretch is described
    /// by exactly one set of coordinates and this road's redundant
    /// approximations of it are removed. Both roads remain - the game needs a
    /// full polyline per path - but their shared trunk is now identical.
    /// A road that lies entirely inside the lower lane is deleted; roads that
    /// merely cross are left alone.
    @MainActor
    func mergeRoadDown(_ upper: Int, mapGeometry: MapGeometry, _ undoManager: UndoManager?) -> String {
        let lower = upper + 1
        guard draft.roads.indices.contains(upper),
              draft.roads.indices.contains(lower) else {
            return "No road below to merge onto"
        }
        let a = draft.roads[upper].points
        let b = draft.roads[lower].points
        let lowerName = draft.roads[lower].name
        guard a.count >= 2, b.count >= 2 else {
            return "Both roads need at least two waypoints"
        }

        let tolerance = mapGeometry.roadHalfWidth
        let inside = a.map { $0.distance(toPolyline: b) <= tolerance }

        if inside.allSatisfy({ $0 }) {
            let name = draft.roads[upper].name
            deleteRoad(upper, undoManager)
            return "\(name) lies entirely on \(lowerName) - removed it"
        }
        guard inside.contains(true) else {
            return "The roads do not overlap - nothing to merge"
        }

        var suffixStart = a.count
        while suffixStart > 0, inside[suffixStart - 1] { suffixStart -= 1 }
        var prefixEnd = -1
        while prefixEnd < a.count - 1, inside[prefixEnd + 1] { prefixEnd += 1 }
        let suffixLength = a.count - suffixStart
        let prefixLength = prefixEnd + 1
        guard suffixLength > 0 || prefixLength > 0 else {
            return "The roads only cross - nothing to merge"
        }

        let arcs = mapGeometry.arcPositions(b)
        // Skip trunk waypoints within this arc distance of the junction so
        // the splice does not produce a kink against the projected point.
        let junctionGap = 12.0
        var merged: [Point]

        if suffixLength >= prefixLength {
            guard let join = mapGeometry.project(a[suffixStart], onto: b),
                  let reference = mapGeometry.project(a[a.count - 1], onto: b) else {
                return "Could not project the junction onto \(lowerName)"
            }
            var tail: [Point] = [join.point]
            if reference.arc >= join.arc {
                for (i, arc) in arcs.enumerated() where arc > join.arc + junctionGap {
                    tail.append(b[i])
                }
            } else {
                for (i, arc) in arcs.enumerated().reversed() where arc < join.arc - junctionGap {
                    tail.append(b[i])
                }
            }
            merged = Array(a[0..<suffixStart]) + tail
        } else {
            guard let join = mapGeometry.project(a[prefixEnd], onto: b),
                  let reference = mapGeometry.project(a[0], onto: b) else {
                return "Could not project the junction onto \(lowerName)"
            }
            var head: [Point] = []
            if join.arc >= reference.arc {
                for (i, arc) in arcs.enumerated() where arc < join.arc - junctionGap {
                    head.append(b[i])
                }
            } else {
                for (i, arc) in arcs.enumerated().reversed() where arc > join.arc + junctionGap {
                    head.append(b[i])
                }
            }
            head.append(join.point)
            merged = head + Array(a[(prefixEnd + 1)...])
        }

        var cleaned: [Point] = []
        for p in merged where (cleaned.last.map { $0.distance(to: p) >= 3 }) ?? true {
            cleaned.append(p)
        }
        if let last = merged.last, cleaned.last != last { cleaned.append(last) }
        guard cleaned.count >= 2 else {
            return "Merging would leave nothing of this road - cancelled"
        }

        let before = a.count
        edit(undoManager) { d in d.roads[upper].points = cleaned }
        return "Merged onto \(lowerName): \(before) waypoints became \(cleaned.count); "
            + "the shared stretch now uses its exact waypoints"
    }
}

struct MapGeometry {
    let virtualCanvas: VirtualCanvas

    var roadHalfWidth: Double { virtualCanvas.pathWidth / 2 }

    private var slotSemiAxes: (a: Double, b: Double) {
        (virtualCanvas.towerSlotSize.width / 2, virtualCanvas.towerSlotSize.height / 2)
    }

    func padClearance(from slot: Point, to pts: [Point]) -> Double {
        guard pts.count >= 2 else { return .infinity }
        let (a, b) = slotSemiAxes
        let ignoreBeyond = roadHalfWidth + Swift.max(a, b)
        var best = Double.infinity
        for i in 0..<(pts.count - 1) {
            let start = pts[i], end = pts[i + 1]
            guard slot.distance(toSegment: start, end) <= ignoreBeyond else { continue }
            best = Swift.min(best, padClearance(from: slot, along: start, end))
            if best == 0 { return 0 }
        }
        return best
    }

    private func padClearance(from slot: Point, along start: Point, _ end: Point) -> Double {
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let third = (high - low) / 3
            let near = low + third, far = high - third
            if padDistance(from: slot, to: along(start, end, near))
                <= padDistance(from: slot, to: along(start, end, far)) {
                high = far
            } else {
                low = near
            }
        }
        return padDistance(from: slot, to: along(start, end, (low + high) / 2))
    }

    private func along(_ start: Point, _ end: Point, _ t: Double) -> Point {
        Point(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t)
    }

    private func padDistance(from slot: Point, to p: Point) -> Double {
        let (a, b) = slotSemiAxes
        guard a > 0, b > 0 else { return slot.distance(to: p) }
        let dx = p.x - slot.x, dy = p.y - slot.y
        if (dx * dx) / (a * a) + (dy * dy) / (b * b) <= 1 { return 0 }
        let px = abs(dx), py = abs(dy)
        var tx = 0.7071067811865476, ty = 0.7071067811865476
        for _ in 0..<4 {
            let ex = (a * a - b * b) * tx * tx * tx / a
            let ey = (b * b - a * a) * ty * ty * ty / b
            let rx = a * tx - ex, ry = b * ty - ey
            let qx = px - ex, qy = py - ey
            let r = (rx * rx + ry * ry).squareRoot()
            let q = (qx * qx + qy * qy).squareRoot()
            guard q > 0 else { break }
            tx = Swift.min(1, Swift.max(0, (qx * r / q + ex) / a))
            ty = Swift.min(1, Swift.max(0, (qy * r / q + ey) / b))
            let norm = (tx * tx + ty * ty).squareRoot()
            guard norm > 0 else { break }
            tx /= norm
            ty /= norm
        }
        let cx = a * tx - px, cy = b * ty - py
        return (cx * cx + cy * cy).squareRoot()
    }

    struct PolylineHit {
        let point: Point
        let arc: Double
    }

    /// Nearest point on the polyline, with its arc-length position along it.
    func project(_ p: Point, onto pts: [Point]) -> PolylineHit? {
        guard pts.count >= 2 else { return nil }
        var best: (d: Double, hit: PolylineHit)?
        var arc = 0.0
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let q = p.closestPoint(onSegment: a, b)
            let d = p.distance(to: q)
            if best == nil || d < best!.d {
                best = (d, PolylineHit(point: q, arc: arc + a.distance(to: q)))
            }
            arc += a.distance(to: b)
        }
        return best?.hit
    }

    func arcPositions(_ pts: [Point]) -> [Double] {
        var out = [0.0]
        for i in 0..<(pts.count - 1) {
            out.append(out[out.count - 1] + pts[i].distance(to: pts[i + 1]))
        }
        return out
    }




    func distance(_ p: Point, segment a: Point, _ b: Point) -> Double {
        p.distance(toSegment: a, b)
    }

    func distance(_ p: Point, polyline pts: [Point]) -> Double {
        p.distance(toPolyline: pts)
    }

    enum SlotIssue {
        /// The pad would sit under a HUD corner, or its radial menu would run
        /// off the play area - a hard error, the slot is unusable there.
        case outsideValidArea
        /// The slot footprint reaches inside a path's lane - a hard error,
        /// nothing may ever sit in the path.
        case overlapsPath
        /// The slot's pad image overlaps another slot's pad - a hard error,
        /// two towers can't share ground.
        case overlapsSlot
        /// No tower placed here could reach any path - a warning.
        case outOfRange

        /// Whether the slot may not be placed here at all, as opposed to
        /// being placeable but useless.
        var blocksPlacement: Bool {
            switch self {
            case .outsideValidArea, .overlapsPath, .overlapsSlot: true
            case .outOfRange: false
            }
        }

        var message: String {
            switch self {
            case .outsideValidArea: "outside the placeable area"
            case .overlapsPath: "intersects a path"
            case .overlapsSlot: "overlaps another slot"
            case .outOfRange: "out of range of every path"
            }
        }
    }

    func slotIssue(_ slot: Point, roads: [MapDraft.Road], others: [Point] = [],
                          maxTowerRange: Double?) -> SlotIssue? {
        if !virtualCanvas.towerSlotValidCentres.contains(CGPoint(x: slot.x, y: slot.y),
                                                         using: .winding) {
            return .outsideValidArea
        }
        let lanes = roads.filter { $0.points.count >= 2 }
        let ds = lanes.map { distance(slot, polyline: $0.points) }
        for lane in lanes where padClearance(from: slot, to: lane.points) < roadHalfWidth {
            return .overlapsPath
        }
        let p = CGPoint(x: slot.x, y: slot.y)
        if others.contains(where: { virtualCanvas.slotFootprintsOverlap(p, CGPoint(x: $0.x, y: $0.y)) }) {
            return .overlapsSlot
        }
        if let d = ds.min(), let maxTowerRange, d - roadHalfWidth > maxTowerRange {
            return .outOfRange
        }
        return nil
    }

    func warnings(for draft: MapDraft, maxTowerRange: Double?) -> [Int: SlotIssue] {
        var out: [Int: SlotIssue] = [:]
        for (i, s) in draft.slots.enumerated() {
            var others = draft.slots
            others.remove(at: i)
            if let w = slotIssue(s, roads: draft.roads, others: others,
                                 maxTowerRange: maxTowerRange) { out[i] = w }
        }
        return out
    }
}
