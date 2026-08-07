// MapDocument.swift
// The .tdmap document: a JSON MapDraft plus undo plumbing. A draft mirrors
// LevelBlueprint field-for-field so the editor can round-trip design-lab
// levels and compile them for playtesting without touching art or the DB.
import SwiftUI
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let tdmap = UTType(exportedAs: "com.zippyzen.td.map")
}

// nonisolated everywhere: the document system encodes, decodes, and compares
// drafts on background threads, so none of these conformances may be bound
// to the main actor.
nonisolated struct MapDraft: Codable, Equatable, Sendable {
    nonisolated struct Road: Codable, Equatable, Sendable {
        var name: String
        var points: [Point]
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

    static let canvasSpace = "canvas2868x2064"

    var name: String
    var startingGold: Int
    var lives: Int
    var roads: [Road]
    var slots: [Point]
    var waves: [Wave]
    var intendedSolution: [BuildStep]
    var backgroundImagePath: String?
    var backgroundOpacity: Double
    var coordinateSpace: String = Self.canvasSpace

    static let starter = MapDraft(
        name: "Untitled Map",
        startingGold: 220,
        lives: 20,
        roads: [],
        slots: [],
        waves: [Wave(breather: 10, lines: [
            SpawnLine(foe: Foe.loyalistMilitia.rawValue, count: 6, every: 2.2, delay: 0, road: 0),
        ])],
        intendedSolution: [],
        backgroundImagePath: nil,
        backgroundOpacity: 0.35
    )

    var isPlayable: Bool {
        roads.contains { $0.points.count >= 2 } && !waves.isEmpty
    }
}

extension MapDraft {
    // Tolerant decoding so hand-edited or older .tdmap files still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Map"
        startingGold = try c.decodeIfPresent(Int.self, forKey: .startingGold) ?? 220
        lives = try c.decodeIfPresent(Int.self, forKey: .lives) ?? 20
        roads = try c.decodeIfPresent([Road].self, forKey: .roads) ?? []
        slots = try c.decodeIfPresent([Point].self, forKey: .slots) ?? []
        waves = try c.decodeIfPresent([Wave].self, forKey: .waves) ?? []
        intendedSolution = try c.decodeIfPresent([BuildStep].self, forKey: .intendedSolution) ?? []
        backgroundImagePath = try c.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.35
        coordinateSpace = try c.decodeIfPresent(String.self, forKey: .coordinateSpace) ?? "design1600x900"
        // Files saved before the retina canvas existed are in engine design
        // space; lift them into canvas pixels.
        if coordinateSpace != Self.canvasSpace {
            for r in roads.indices {
                roads[r].points = roads[r].points.map(CanvasSpec.fromDesign)
            }
            slots = slots.map(CanvasSpec.fromDesign)
            coordinateSpace = Self.canvasSpace
        }
    }

    init(blueprint bp: LevelBlueprint) {
        self.init(
            name: bp.name,
            startingGold: bp.startingGold,
            lives: bp.lives,
            roads: bp.roads.map { Road(name: $0.name, points: $0.waypoints.map(CanvasSpec.fromDesign)) },
            slots: bp.slots.map(CanvasSpec.fromDesign),
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
            backgroundOpacity: 0.35
        )
    }

    func makeBlueprint() -> LevelBlueprint {
        LevelBlueprint(
            name: name,
            startingGold: startingGold,
            lives: lives,
            roads: roads.filter { $0.points.count >= 2 }
                .map { LevelBlueprint.Road($0.name, $0.points.map(CanvasSpec.toDesign)) },
            slots: slots.map(CanvasSpec.toDesign),
            waves: waves.map { w in
                LevelBlueprint.WaveSketch(breather: w.breather, lines: w.lines.map { l in
                    LevelBlueprint.SpawnLine(
                        Foe(rawValue: l.foe) ?? .loyalistMilitia,
                        count: l.count, every: l.every, delay: l.delay,
                        road: min(l.road, max(0, roads.count - 1))
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

    static var readableContentTypes: [UTType] { [.tdmap] }
    static var writableContentTypes: [UTType] { [.tdmap] }

    init() {
        draft = .starter
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        draft = try JSONDecoder().decode(MapDraft.self, from: data)
    }

    func snapshot(contentType: UTType) throws -> MapDraft { draft }

    func fileWrapper(snapshot: MapDraft, configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(snapshot))
    }

    // MARK: - Undoable editing

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

    // MARK: - Structural edits shared by canvas and inspector

    // Removing a slot renumbers everything after it, so intended-solution
    // steps must be dropped or shifted to keep referring to the same towers.
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
    func deleteWaypoint(road r: Int, point i: Int, _ undoManager: UndoManager?) {
        edit(undoManager) { d in
            guard d.roads.indices.contains(r), d.roads[r].points.indices.contains(i) else { return }
            d.roads[r].points.remove(at: i)
        }
    }
}

// MARK: - Geometry checks

// All distances in canvas pixels: engine design units x CanvasSpec.designScale.
enum MapGeometry {
    static let roadHalfWidth = 15.0 * CanvasSpec.designScale
    static let slotRadius = 16.0 * CanvasSpec.designScale
    static let maxTowerRange = 220.0 * CanvasSpec.designScale

    static func distance(_ p: Point, segment a: Point, _ b: Point) -> Double {
        let ab = Point(b.x - a.x, b.y - a.y)
        let len2 = ab.x * ab.x + ab.y * ab.y
        guard len2 > 0 else { return p.distance(to: a) }
        let t = max(0, min(1, ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2))
        return p.distance(to: Point(a.x + ab.x * t, a.y + ab.y * t))
    }

    static func distance(_ p: Point, polyline pts: [Point]) -> Double {
        guard let first = pts.first else { return .infinity }
        guard pts.count > 1 else { return p.distance(to: first) }
        var best = Double.infinity
        for i in 0..<(pts.count - 1) {
            best = min(best, distance(p, segment: pts[i], pts[i + 1]))
        }
        return best
    }

    static func slotWarning(_ slot: Point, roads: [MapDraft.Road]) -> String? {
        let ds = roads.filter { !$0.points.isEmpty }.map { distance(slot, polyline: $0.points) }
        guard let d = ds.min() else { return nil }
        if d < roadHalfWidth + slotRadius { return "overlaps a road" }
        if d - roadHalfWidth > maxTowerRange { return "out of range of every road" }
        return nil
    }

    static func warnings(for draft: MapDraft) -> [Int: String] {
        var out: [Int: String] = [:]
        for (i, s) in draft.slots.enumerated() {
            if let w = slotWarning(s, roads: draft.roads) { out[i] = w }
        }
        return out
    }
}
