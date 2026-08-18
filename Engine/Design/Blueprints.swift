//import Foundation
//
//public enum Blueprints {
//    public static let all: [LevelBlueprint] = [singleRoad, convergingRoads]
//
//    public static let singleRoad = LevelBlueprint(
//        canvasSpec: canvasSpec,
//        name: "Single Road",
//        startingGold: 220,
//        lives: 20,
//        roads: [
//            LevelBlueprint.Road("Bay Road", [
//                Point(2358, 1260), Point(1914, 1278), Point(1554, 1236), Point(1290, 1176),
//                Point(1140, 1074), Point(1092, 936), Point(1158, 822),
//                Point(834, 756), Point(510, 744),
//            ]),
//        ],
//        slots: [
//            Point(1974, 1152),
//            Point(1650, 1356),
//            Point(1386, 1068),
//            Point(1218, 1008),
//            Point(990, 900),
//            Point(750, 864),
//            Point(1014, 636),
//            Point(618, 636),
//        ],
//        waves: [
//            .init(breather: 10, lines: [
//                .init(.loyalistMilitia, count: 6, every: 2.2),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.loyalistMilitia, count: 8, every: 1.9),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.loyalistMilitia, count: 6, every: 1.9),
//                .init(.redcoatRegular, count: 3, every: 2.6, delay: 3),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.redcoatRegular, count: 9, every: 1.7),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.lightInfantry, count: 7, every: 1.3),
//                .init(.loyalistMilitia, count: 5, every: 1.8, delay: 2),
//            ]),
//            .init(breather: 15, lines: [
//                .init(.redcoatRegular, count: 12, every: 1.4),
//                .init(.lightInfantry, count: 5, every: 1.5, delay: 5),
//            ]),
//        ],
//        intendedSolution: [
//            .init(at: 1, .place(.minutemanPost, slot: 3)),
//            .init(at: 2, .place(.minutemanPost, slot: 0)),
//            .init(at: 35, .upgrade(slot: 3)),
//            .init(at: 60, .place(.minutemanPost, slot: 2)),
//            .init(at: 90, .place(.minutemanPost, slot: 4)),
//            .init(at: 120, .upgrade(slot: 0)),
//            .init(at: 150, .upgrade(slot: 2)),
//            .init(at: 185, .upgrade(slot: 3)),
//        ]
//    )
//
//    public static func named(_ name: String) -> LevelBlueprint? {
//        all.first { $0.name.lowercased() == name.lowercased() }
//    }
//
//    public static let convergingRoads = LevelBlueprint(
//        name: "Converging Roads",
//        startingGold: 500,
//        lives: 20,
//        roads: [
//            LevelBlueprint.Road("North Road", [
//                Point(510, 1416), Point(906, 1440), Point(1218, 1356),
//                Point(1386, 1176), Point(1554, 1032),
//                Point(1746, 1152), Point(1950, 948), Point(2178, 1068), Point(2370, 1032),
//            ]),
//            LevelBlueprint.Road("Creek Trail", [
//                Point(510, 648), Point(834, 612), Point(1122, 708),
//                Point(1314, 900), Point(1554, 1032),
//                Point(1746, 1152), Point(1950, 948), Point(2178, 1068), Point(2370, 1032),
//            ]),
//        ],
//        slots: [
//            Point(774, 1320),
//            Point(1194, 1248),
//            Point(1470, 1272),
//            Point(858, 744),
//            Point(1182, 840),
//            Point(1422, 840),
//            Point(1542, 900),
//            Point(1656, 1062),
//            Point(1830, 1092),
//            Point(2070, 924),
//            Point(2250, 1164),
//            Point(1362, 1026),
//        ],
//        waves: [
//            .init(breather: 8, lines: [
//                .init(.loyalistMilitia, count: 8, every: 2.0, road: 0),
//            ]),
//            .init(breather: 12, lines: [
//                .init(.loyalistMilitia, count: 6, every: 2.0, road: 1),
//                .init(.loyalistMilitia, count: 4, every: 2.0, delay: 4, road: 0),
//            ]),
//            .init(breather: 12, lines: [
//                .init(.redcoatRegular, count: 6, every: 2.2, road: 0),
//                .init(.regimentalDrummer, count: 1, every: 1, delay: 2.2, road: 0),
//                .init(.loyalistMilitia, count: 6, every: 1.8, delay: 3, road: 1),
//            ]),
//            .init(breather: 13, lines: [
//                .init(.lightInfantry, count: 8, every: 1.2, road: 1),
//                .init(.redcoatRegular, count: 4, every: 2.2, delay: 2, road: 0),
//            ]),
//            .init(breather: 13, lines: [
//                .init(.hessianJager, count: 6, every: 1.6, road: 1),
//                .init(.hessianFusilier, count: 4, every: 2.4, road: 0),
//                .init(.regimentalDrummer, count: 1, every: 1, delay: 3, road: 0),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.lightDragoon, count: 3, every: 1.4, road: 0),
//                .init(.lightDragoon, count: 3, every: 1.4, delay: 2, road: 1),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.grenadier, count: 4, every: 4.0, road: 0),
//                .init(.regimentalDrummer, count: 2, every: 6.0, delay: 1.5, road: 0),
//                .init(.redcoatRegular, count: 10, every: 1.4, delay: 2, road: 1),
//            ]),
//            .init(breather: 13, lines: [
//                .init(.mountedOfficer, count: 1, every: 1, delay: 3, road: 1),
//                .init(.hessianFusilier, count: 8, every: 1.6, road: 1),
//                .init(.lightInfantry, count: 7, every: 1.4, delay: 1, road: 0),
//            ]),
//            .init(breather: 14, lines: [
//                .init(.royalArtillery, count: 3, every: 8.0, road: 0),
//                .init(.grenadier, count: 2, every: 4.0, delay: 6, road: 0),
//                .init(.lightDragoon, count: 5, every: 1.2, delay: 22, road: 1),
//            ]),
//            .init(breather: 13, lines: [
//                .init(.highlander, count: 6, every: 1.6, road: 0),
//                .init(.regimentalDrummer, count: 1, every: 1, delay: 2, road: 0),
//                .init(.highlander, count: 4, every: 1.6, delay: 3, road: 1),
//                .init(.regimentalDrummer, count: 1, every: 1, delay: 5, road: 1),
//                .init(.lightInfantry, count: 5, every: 1.3, delay: 7, road: 1),
//            ]),
//            .init(breather: 15, lines: [
//                .init(.footGuards, count: 3, every: 5.0, road: 0),
//                .init(.regimentalDrummer, count: 2, every: 8.0, delay: 2, road: 0),
//                .init(.grenadier, count: 4, every: 3.0, delay: 4, road: 1),
//                .init(.mountedOfficer, count: 1, every: 1, delay: 8, road: 1),
//                .init(.lightDragoon, count: 4, every: 1.3, delay: 16, road: 1),
//                .init(.lightDragoon, count: 3, every: 1.3, delay: 24, road: 0),
//            ]),
//        ],
//        intendedSolution: [
//            .init(at: 1, .place(.minutemanPost, slot: 7)),
//            .init(at: 2, .place(.minutemanPost, slot: 0)),
//            .init(at: 3, .place(.minutemanPost, slot: 3)),
//            .init(at: 22, .place(.libertyPole, slot: 5)),
//            .init(at: 45, .place(.longRifles, slot: 11)),
//            .init(at: 65, .upgrade(slot: 7)),
//            .init(at: 85, .place(.fieldBattery, slot: 8)),
//            .init(at: 100, .upgrade(slot: 5)),
//            .init(at: 122, .upgrade(slot: 0)),
//            .init(at: 140, .upgrade(slot: 3)),
//            .init(at: 160, .upgrade(slot: 11)),
//            .init(at: 180, .upgrade(slot: 8)),
//            .init(at: 205, .place(.minutemanPost, slot: 6)),
//            .init(at: 228, .upgrade(slot: 7)),
//            .init(at: 250, .upgrade(slot: 11)),
//            .init(at: 275, .place(.longRifles, slot: 2)),
//            .init(at: 300, .upgrade(slot: 2)),
//            .init(at: 325, .upgrade(slot: 8)),
//            .init(at: 350, .place(.libertyPole, slot: 9)),
//            .init(at: 375, .upgrade(slot: 9)),
//            .init(at: 400, .upgrade(slot: 6)),
//            .init(at: 425, .upgrade(slot: 5)),
//            .init(at: 450, .upgrade(slot: 2)),
//        ]
//    )
//}
