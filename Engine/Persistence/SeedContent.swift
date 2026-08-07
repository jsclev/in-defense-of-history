//// SeedContent.swift
//// First-run content: the Crown Forces enemy roster from the design document,
//// a starter American tower set, and one demo level so `revsim` runs end-to-end
//// out of the box. All of it is ordinary database content — edit or replace via
//// the repository; nothing here is hard-coded into the engine.
////
//// Speed tiers (virtual units/sec): V.Slow 25, Slow 40, Med 60, Fast 85, V.Fast 120.
//// breakBand: fraction of max morale where Shaken begins, sampled per unit.
//// Green troops break high; elites hold to the last.
//import Foundation
//
//public enum SeedContent {
//    // MARK: - Crown Forces roster
//
//    public static func crownForces() -> [EnemyType] {
//        [
//            EnemyType(
//                id: UUID(),
//                name: "Loyalist Militia",
//                stats: EnemyStats(maxHP: 50, speed: 60, cover: 0.35, discipline: 0.20,
//                                  hardiness: 0.30, damageMin: 2, damageMax: 4,
//                                  gold: 8, livesCost: 1, breakBand: 0.45...0.65),
//                traits: [.wavering]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Regimental Drummer",
//                stats: EnemyStats(maxHP: 60, speed: 60, cover: 0.10, discipline: 0.55,
//                                  hardiness: 0.60, damageMin: 0, damageMax: 0,
//                                  gold: 20, livesCost: 1, breakBand: 0.35...0.50),
//                traits: [.rallyBeat(radius: 90, moralePerSecond: 6)]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Redcoat Regular",
//                stats: EnemyStats(maxHP: 90, speed: 60, cover: 0.05, discipline: 0.60,
//                                  hardiness: 0.70, damageMin: 4, damageMax: 7,
//                                  gold: 15, livesCost: 1, breakBand: 0.30...0.45),
//                traits: []
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Light Infantry",
//                stats: EnemyStats(maxHP: 70, speed: 85, cover: 0.45, discipline: 0.50,
//                                  hardiness: 0.60, damageMin: 3, damageMax: 6,
//                                  gold: 18, livesCost: 1, breakBand: 0.30...0.45),
//                traits: [.skirmish]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Hessian Jäger",
//                stats: EnemyStats(maxHP: 65, speed: 85, cover: 0.55, discipline: 0.45,
//                                  hardiness: 0.55, damageMin: 6, damageMax: 9,
//                                  gold: 22, livesCost: 1, breakBand: 0.30...0.45),
//                traits: [.mercenary, .marksman]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Hessian Fusilier",
//                stats: EnemyStats(maxHP: 110, speed: 60, cover: 0.05, discipline: 0.70,
//                                  hardiness: 0.65, damageMin: 5, damageMax: 8,
//                                  gold: 20, livesCost: 1, breakBand: 0.28...0.40),
//                traits: [.mercenary]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Native Warrior",
//                stats: EnemyStats(maxHP: 60, speed: 120, cover: 0.60, discipline: 0.35,
//                                  hardiness: 0.75, damageMin: 5, damageMax: 8,
//                                  gold: 20, livesCost: 1, breakBand: 0.35...0.55),
//                traits: [.skirmish, .tag("ambush")]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Highlander",
//                stats: EnemyStats(maxHP: 130, speed: 85, cover: 0.10, discipline: 0.75,
//                                  hardiness: 0.75, damageMin: 8, damageMax: 12,
//                                  gold: 30, livesCost: 1, breakBand: 0.25...0.35),
//                traits: [.highlandCharge]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Light Dragoon",
//                stats: EnemyStats(maxHP: 140, speed: 120, cover: 0.15, discipline: 0.65,
//                                  hardiness: 0.60, damageMin: 7, damageMax: 11,
//                                  gold: 35, livesCost: 1, breakBand: 0.28...0.40),
//                traits: [.rideDown, .falter]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Spy",
//                stats: EnemyStats(maxHP: 45, speed: 85, cover: 0.70, discipline: 0.40,
//                                  hardiness: 0.50, damageMin: 1, damageMax: 2,
//                                  gold: 25, livesCost: 0, breakBand: 0.35...0.50),
//                traits: [.disguised, .saboteur]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Grenadier",
//                stats: EnemyStats(maxHP: 240, speed: 40, cover: 0.0, discipline: 0.85,
//                                  hardiness: 0.75, damageMin: 10, damageMax: 15,
//                                  gold: 45, livesCost: 2, breakBand: 0.22...0.30),
//                traits: [.steadyAdvance]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Royal Artillery",
//                stats: EnemyStats(maxHP: 300, speed: 25, cover: 0.10, discipline: 0.70,
//                                  hardiness: 0.65, damageMin: 15, damageMax: 25,
//                                  gold: 60, livesCost: 2, breakBand: 0.25...0.35),
//                traits: [.bombard, .crewed]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Mounted Officer",
//                stats: EnemyStats(maxHP: 180, speed: 85, cover: 0.10, discipline: 0.90,
//                                  hardiness: 0.70, damageMin: 6, damageMax: 10,
//                                  gold: 50, livesCost: 2, breakBand: 0.20...0.30),
//                traits: [.commandAura(radius: 120, disciplineBonus: 0.25, deathShock: 25)]
//            ),
//            EnemyType(
//                id: UUID(),
//                name: "Foot Guards",
//                stats: EnemyStats(maxHP: 500, speed: 40, cover: 0.0, discipline: 1.0,
//                                  hardiness: 0.85, damageMin: 12, damageMax: 20,
//                                  gold: 75, livesCost: 3, breakBand: 0.15...0.25),
//                traits: [.steadyAdvance, .tag("unbreakable")]
//            ),
//        ]
//    }
//
//    // MARK: - Starter tower set (working names; four demo towers, two levels each)
//
//    public static func starterTowers() -> [TowerType] {
//        [
//            TowerType(id: UUID(), name: "Minuteman Post", levels: [
//                TowerLevel(cost: 70, range: 140, fireInterval: 0.9,
//                           shotMin: 4, shotMax: 7),
//                TowerLevel(cost: 90, range: 150, fireInterval: 0.85,
//                           shotMin: 7, shotMax: 11),
//            ]),
//            TowerType(id: UUID(), name: "Long Rifle Perch", levels: [
//                TowerLevel(cost: 100, range: 220, fireInterval: 2.2,
//                           shotMin: 18, shotMax: 26, targeting: .strongest),
//                TowerLevel(cost: 130, range: 235, fireInterval: 2.1,
//                           shotMin: 27, shotMax: 38, targeting: .strongest),
//            ]),
//            TowerType(id: UUID(), name: "Field Cannon", levels: [
//                TowerLevel(cost: 125, range: 170, fireInterval: 3.0,
//                           shotMin: 10, shotMax: 16, terrorMin: 8, terrorMax: 14,
//                           aoeRadius: 55),
//                TowerLevel(cost: 160, range: 180, fireInterval: 2.8,
//                           shotMin: 15, shotMax: 22, terrorMin: 12, terrorMax: 18,
//                           aoeRadius: 62),
//            ]),
//            TowerType(id: UUID(), name: "Volley Line", levels: [
//                TowerLevel(cost: 90, range: 130, fireInterval: 1.6,
//                           shotMin: 3, shotMax: 5, terrorMin: 10, terrorMax: 16,
//                           targeting: .shakiest),
//                TowerLevel(cost: 120, range: 140, fireInterval: 1.5,
//                           shotMin: 4, shotMax: 7, terrorMin: 15, terrorMax: 22,
//                           targeting: .shakiest),
//            ]),
//        ]
//    }
//
//    // MARK: - Demo level
//
//    /// "Concord Road" — a single winding path in a 1280x640 virtual canvas
//    /// (author art at any resolution; these coordinates are the shared space).
//    public static func concordRoad() -> LevelInfo {
//        LevelInfo(
//            id: UUID(),
//            name: "Concord Road",
//            campaign: Campaign(id: UUID(), name: "campaign"),
//            startedAt: Date.now,
//            endedAt: Date.now,
//            startingMoney: 260,
//            numStartingLives: 20,
//            paths: [
//                Path(points: [
//                    Point(-40, 300), Point(160, 260), Point(360, 330),
//                    Point(560, 270), Point(760, 330), Point(960, 280),
//                    Point(1160, 310), Point(1240, 300),
//                ]),
//            ],
//            towerSlots: [
//                TowerSlot(index: 0, position: Point(120, 200)),
//                TowerSlot(index: 1, position: Point(300, 390)),
//                TowerSlot(index: 2, position: Point(480, 210)),
//                TowerSlot(index: 3, position: Point(660, 390)),
//                TowerSlot(index: 4, position: Point(840, 230)),
//                TowerSlot(index: 5, position: Point(1020, 350)),
//                TowerSlot(index: 6, position: Point(560, 180)),
//                TowerSlot(index: 7, position: Point(900, 380)),
//            ],
//            waves: [
//                Wave(startTime: 5, spawns: [
//                    SpawnEntry(enemyTypeID: UUID(), count: 8, interval: 1.3),
//                ]),
//                Wave(startTime: 40, spawns: [
//                    SpawnEntry(enemyTypeID: UUID(), count: 6, interval: 1.1),
//                    SpawnEntry(enemyTypeID: UUID(), count: 4, interval: 1.6, delay: 4),
//                ]),
//                Wave(startTime: 80, spawns: [
//                    SpawnEntry(enemyTypeID: UUID(), count: 6, interval: 1.0),
//                    SpawnEntry(enemyTypeID: UUID(), count: 6, interval: 1.4, delay: 3),
//                    SpawnEntry(enemyTypeID: UUID(), count: 1, interval: 1.0, delay: 6),
//                ]),
//                Wave(startTime: 125, spawns: [
//                    SpawnEntry(enemyTypeID: UUID(), count: 5, interval: 1.5),
//                    SpawnEntry(enemyTypeID: UUID(), count: 4, interval: 1.2, delay: 2),
//                    SpawnEntry(enemyTypeID: UUID(), count: 1, interval: 1.0, delay: 5),
//                ]),
//                Wave(startTime: 175, spawns: [
//                    SpawnEntry(enemyTypeID: UUID(), count: 8, interval: 1.2),
//                    SpawnEntry(enemyTypeID: UUID(), count: 1, interval: 1.0, delay: 3),
//                    SpawnEntry(enemyTypeID: UUID(), count: 2, interval: 4.0, delay: 6),
//                    SpawnEntry(enemyTypeID: UUID(), count: 1, interval: 1.0, delay: 8),
//                ]),
//            ]
//        )
//    }
//
//    // MARK: - Seeding
//
//    /// Populates an empty database. No-op if content already exists.
//    @discardableResult
//    public static func seedIfNeeded(into repo: ContentRepository) throws -> Bool {
//        guard try repo.isEmpty() else { return false }
//        for enemy in crownForces() { try repo.save(enemy) }
//        for tower in starterTowers() { try repo.save(tower) }
//        try repo.save(concordRoad())
//        return true
//    }
//}
