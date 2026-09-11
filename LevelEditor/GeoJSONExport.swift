import Foundation
import CoreGraphics
import UniformTypeIdentifiers

extension UTType {
    static let geoJSON = UTType("public.geojson") ?? UTType(exportedAs: "com.zippyzen.td.geojson")
}

struct GeoJSONExport {
    let virtualCanvas: VirtualCanvas

    func data(for draft: MapDraft) throws -> Data {
        try document(for: draft).data()
    }

    func filename(for draft: MapDraft) -> String {
        let base = draft.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .lowercased()
        return (base.isEmpty ? "untitled_map" : base) + ".geojson"
    }

    func document(for source: MapDraft) throws -> LevelGeoJSON {
        // Export a copy, including normalization of legacy eraser layers.
        // The editable roads, names, wave assignments and paint stay intact.
        var draft = source
        draft.normalize(mapGeometry: MapGeometry(virtualCanvas: virtualCanvas))
        guard !draft.entrances.isEmpty else {
            throw LevelGeoJSON.ValidationError(message: "Place at least one entrance before exporting GeoJSON.")
        }
        guard !draft.exits.isEmpty else {
            throw LevelGeoJSON.ValidationError(message: "Place at least one exit before exporting GeoJSON.")
        }
        guard !draft.callWaveButtons.isEmpty else {
            throw LevelGeoJSON.ValidationError(message: "Place at least one call wave button before exporting GeoJSON.")
        }
        guard virtualCanvas.pathWidth.isFinite, virtualCanvas.pathWidth > 0 else {
            throw LevelGeoJSON.ValidationError(message: "Path width must be finite and positive.")
        }
        for road in draft.roads {
            if let cutout = road.erasedArea { try cutout.validate() }
            guard road.points.count >= 2, Set(road.points).count >= 2,
                  road.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                throw LevelGeoJSON.ValidationError(message: "Road \(road.name) needs at least two distinct, finite waypoints.")
            }
        }
        for stroke in draft.roadPaint {
            if let cutout = stroke.erasedArea { try cutout.validate() }
            guard !stroke.points.isEmpty, stroke.width.isFinite, stroke.width > 0,
                  stroke.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                throw LevelGeoJSON.ValidationError(message: "Paint needs finite points and a positive width.")
            }
        }
        if let base = draft.flattenedPath, base != .multiPolygon([]) { try base.validate() }
        let area = BrushGeometry.roadArea(roads: draft.roads, paint: draft.roadPaint,
                                         roadHalfWidth: virtualCanvas.pathWidth / 2,
                                         base: draft.flattenedPath)
        let path = try PathFlattening.geometry(from: area)
        func feature(id: String, name: String, kind: LevelGeoJSON.Kind,
                     geometry: LevelGeoJSON.Geometry, slot: Int? = nil,
                     pathIndices: [Int]? = nil, heroRoles: [HeroSelection.Role]? = nil) -> LevelGeoJSON.Feature {
            let inside = geometry.positions.allSatisfy {
                virtualCanvas.playAreaRect.contains(CGPoint(x: $0[0], y: $0[1]))
            }
            return .init(id: id, geometry: geometry,
                         properties: .init(id: id, name: name, kind: kind,
                                           layer: kind == .callWaveButton ? 100 : (kind == .path ? 40 : 75),
                                           insidePlayArea: inside,
                                           pathIndex: [.towerSlot, .callWaveButton, .heroSpawn].contains(kind) ? nil : 0,
                                           slotIndex: slot, slotNumber: slot.map { $0 + 1 },
                                           pathIndices: pathIndices, heroRoles: heroRoles))
        }
        var features = [feature(id: "gameplay.road", name: "Path", kind: .path, geometry: path)]
        for route in draft.enemyRoutes {
            let id = "gameplay.enemy_route.\(route.index)"
            features.append(.init(id: id,
                geometry: .lineString(route.points.map { [$0.x, $0.y] }),
                properties: .init(id: id, name: route.name, kind: .enemyRoute, layer: 45,
                    insidePlayArea: route.points.allSatisfy { virtualCanvas.playAreaRect.contains(CGPoint(x: $0.x, y: $0.y)) },
                    pathIndex: route.index, entranceID: route.entranceID, exitID: route.exitID)))
        }
        for (i, p) in draft.entrances.enumerated() {
            features.append(feature(id: "gameplay.entry.\(i)", name: "Entrance \(i + 1)",
                                    kind: .entrance, geometry: .point([p.x, p.y])))
        }
        for (i, p) in draft.exits.enumerated() {
            features.append(feature(id: "gameplay.exit.\(i)", name: "Exit \(i + 1)",
                                    kind: .exit, geometry: .point([p.x, p.y])))
        }
        for role in HeroSelection.Role.allCases where draft.hasHero(role) {
            if let p = draft.heroPosition(role) {
                features.append(feature(id: "gameplay.hero_spawn.\(role.rawValue)", name: role.title,
                                        kind: .heroSpawn, geometry: .point([p.x, p.y]), heroRoles: [role]))
            }
        }
        for (i, p) in draft.slots.enumerated() {
            features.append(feature(id: "gameplay.tower_slot.\(i + 1)", name: "Tower slot \(i + 1)",
                                    kind: .towerSlot, geometry: .point([p.x, p.y]), slot: i))
        }
        for (i, p) in draft.callWaveButtons.enumerated() {
            features.append(feature(id: "gameplay.call_wave_button.\(i)", name: "Call wave button \(i + 1)",
                                    kind: .callWaveButton, geometry: .point([p.x, p.y]),
                                    pathIndices: p.pathIndices))
        }
        let rect = virtualCanvas.playAreaRect
        return try LevelGeoJSON(collection: .init(
            name: draft.name,
            coordinateReferenceSystem: .init(
                canvas: .init(width: virtualCanvas.size.width, height: virtualCanvas.size.height),
                playArea: .init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)),
            startingGold: draft.startingGold, lives: draft.lives, features: features,
            waves: draft.waves.map { w in
                .init(breather: w.breather, lines: w.lines.map { l in
                    .init(foe: l.foe, count: l.count, every: l.every, delay: l.delay,
                          pathIndex: draft.enemyRoutes.isEmpty && draft.flattenedPath == nil ? 0 : l.road)
                }, callButtonDelay: w.callButtonDelay, autoStartCountdown: w.autoStartCountdown,
                      earlyCallBonus: w.earlyCallBonus)
            }, heroCount: draft.heroCount))
    }
}
