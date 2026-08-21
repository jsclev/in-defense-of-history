import SwiftUI
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let tdmap = UTType(exportedAs: "com.zippyzen.td.map")
}

nonisolated struct MapDraft: Codable, Equatable, Sendable {
    nonisolated struct Road: Codable, Equatable, Sendable {
        var name: String
        var points: [Point]

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

    nonisolated struct PaintStroke: Codable, Equatable, Sendable {
        var points: [Point]
        var width: Double
        var erases: Bool
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

    /// Merges an eraser stroke straight into the waypoints. Covered waypoints go
    /// away, a road cut through the middle becomes two roads, and painted area
    /// under the eraser is cut the same way. The stroke itself is not kept.
    mutating func applyErase(_ eraser: PaintStroke, geometry: MapGeometry) {
        var taken = Set(roads.map(\.name))
        var cut: [Road] = []
        var firstPiece: [Int: Int] = [:]
        for (old, road) in roads.enumerated() {
            let pieces = BrushGeometry.erase(polyline: road.points,
                                             halfWidth: geometry.roadHalfWidth,
                                             with: eraser)
                .filter { $0.count >= 2 }
            for (i, points) in pieces.enumerated() {
                if i == 0 { firstPiece[old] = cut.count }
                let name = i == 0 ? road.name : Self.freeRoadName(taken: taken)
                taken.insert(name)
                cut.append(Road(name: name, points: points))
            }
        }
        roads = cut
        // Spawn lines address a road by position, so a split or a road erased
        // away renumbers them. A line follows its road to the first piece that
        // survived; a road erased away entirely falls back to road 0, the same
        // fallback deleteRoad uses.
        for w in waves.indices {
            for l in waves[w].lines.indices {
                waves[w].lines[l].road = firstPiece[waves[w].lines[l].road] ?? 0
            }
        }
        roadPaint = roadPaint.flatMap { stroke in
            BrushGeometry.erase(polyline: stroke.points, halfWidth: stroke.width / 2,
                                with: eraser)
                .map { PaintStroke(points: $0, width: stroke.width, erases: false) }
        }
    }

    /// A draft authored before the eraser merged down stored its eraser strokes
    /// as a layer. Replay them in author order and drop them, so no draft in
    /// memory ever carries one.
    mutating func bakeStoredErasures(geometry: MapGeometry) {
        guard roadPaint.contains(where: \.erases) else { return }
        let strokes = roadPaint
        roadPaint = []
        for stroke in strokes {
            if stroke.erases {
                applyErase(stroke, geometry: geometry)
            } else {
                roadPaint.append(stroke)
            }
        }
    }

    /// THE road name allocator. Erasing can split and drop roads, so a name
    /// taken from the count alone would collide with a road already there.
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
        slots = try c.decodeIfPresent([Point].self, forKey: .slots) ?? []
        entrances = try c.decodeIfPresent([Point].self, forKey: .entrances) ?? []
        exits = try c.decodeIfPresent([Point].self, forKey: .exits) ?? []
        waves = try c.decodeIfPresent([Wave].self, forKey: .waves) ?? []
        intendedSolution = try c.decodeIfPresent([BuildStep].self, forKey: .intendedSolution) ?? []
        backgroundImagePath = try c.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.35
        overlayImagePath = try c.decodeIfPresent(String.self, forKey: .overlayImagePath)
        guideImagePath = try c.decodeIfPresent(String.self, forKey: .guideImagePath)
        guideOpacity = try c.decodeIfPresent(Double.self, forKey: .guideOpacity) ?? 0.5
        coordinateSpace = try c.decodeIfPresent(String.self, forKey: .coordinateSpace) ?? "design1600x900"
        roadPaint = try c.decodeIfPresent([PaintStroke].self, forKey: .roadPaint) ?? []
    }

    /// Brings a freshly opened draft into the canonical space: legacy
    /// coordinate spaces are converted and stored eraser strokes baked. Both
    /// need the canvas, which a Decodable init cannot receive, so this runs
    /// right after open instead of inside decoding.
    mutating func normalize(geometry: MapGeometry) {
        if coordinateSpace != Self.canvasSpace {
            let vc = geometry.virtualCanvas
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
            slots = slots.map(upgrade)
            entrances = entrances.map(upgrade)
            exits = exits.map(upgrade)
            coordinateSpace = Self.canvasSpace
        }
        bakeStoredErasures(geometry: geometry)
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
    typealias Snapshot = MapDraft

    @Published var draft: MapDraft

    // .geojson is readable so a level can be opened straight from its single
    // source of truth. Writing stays .tdmap only: the GeoJSON is authored by the
    // generator, and the editor saving over it would fork the source.
    static var readableContentTypes: [UTType] { [.tdmap, .geoJSON] }
    static var writableContentTypes: [UTType] { [.tdmap] }

    init() {
        draft = .starter
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if configuration.contentType == .geoJSON {
            draft = try GeoJSONImport.draft(from: data)
        } else {
            draft = try JSONDecoder().decode(MapDraft.self, from: data)
        }
    }

    func snapshot(contentType: UTType) throws -> MapDraft { draft }

    func fileWrapper(snapshot: MapDraft, configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(snapshot))
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
    func deleteEntrance(_ i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.entrances.indices.contains(i) else { return }
            d.entrances.remove(at: i)
        }
    }

    @MainActor
    func deleteExit(_ i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.exits.indices.contains(i) else { return }
            d.exits.remove(at: i)
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
    func mergeRoadDown(_ upper: Int, geometry: MapGeometry, _ undoManager: UndoManager?) -> String {
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

        let tolerance = geometry.roadHalfWidth
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

        let arcs = geometry.arcPositions(b)
        // Skip trunk waypoints within this arc distance of the junction so
        // the splice does not produce a kink against the projected point.
        let junctionGap = 12.0
        var merged: [Point]

        if suffixLength >= prefixLength {
            guard let join = geometry.project(a[suffixStart], onto: b),
                  let reference = geometry.project(a[a.count - 1], onto: b) else {
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
            guard let join = geometry.project(a[prefixEnd], onto: b),
                  let reference = geometry.project(a[0], onto: b) else {
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

    /// Vertical semi-axis of the slot footprint in virtual_canvas. Roads run
    /// mostly horizontally, so this is the reach of the pad toward a road for
    /// the overlap warning; the drawn pad uses the full footprint ellipse.
    var slotRadius: Double { virtualCanvas.towerSlotSize.height / 2 }

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
        /// The slot footprint reaches inside a path's lane - a hard error,
        /// nothing may ever sit in the path.
        case overlapsPath
        /// The slot's pad image overlaps another slot's pad - a hard error,
        /// two towers can't share ground.
        case overlapsSlot
        /// No tower placed here could reach any path - a warning.
        case outOfRange

        var message: String {
            switch self {
            case .overlapsPath: "intersects a path"
            case .overlapsSlot: "overlaps another slot"
            case .outOfRange: "out of range of every path"
            }
        }
    }

    /// `maxTowerRange` is the longest range in the tower table, supplied by the
    /// caller rather than read from a singleton so this stays pure geometry.
    /// Passing nil skips the range check instead of comparing against an
    /// invented constant. `others` are the remaining slots, tested with the
    /// pad IMAGE's footprint (VirtualCanvas), so spacing is set by the art.
    func slotIssue(_ slot: Point, roads: [MapDraft.Road], others: [Point] = [],
                          maxTowerRange: Double?) -> SlotIssue? {
        let ds = roads.filter { !$0.points.isEmpty }.map { distance(slot, polyline: $0.points) }
        if let d = ds.min(), d < roadHalfWidth + slotRadius { return .overlapsPath }
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
