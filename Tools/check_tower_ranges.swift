import Foundation
import CoreGraphics
import SQLite3

@main
enum TowerRangeCheck {
    static func near(_ a: Double, _ b: Double, tolerance: Double = 0.000001) {
        precondition(abs(a - b) < tolerance, "Mismatch: \(a) versus \(b)")
    }

    static func rows(_ sql: String, db: OpaquePointer) -> [[String: String]] {
        var statement: OpaquePointer?
        precondition(sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var result: [[String: String]] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                if let value = sqlite3_column_text(statement, index) {
                    row[String(cString: sqlite3_column_name(statement, index))] = String(cString: value)
                }
            }
            result.append(row)
            status = sqlite3_step(statement)
        }
        precondition(status == SQLITE_DONE)
        return result
    }

    static func main() {
        var connection: OpaquePointer?
        let path = CommandLine.arguments.dropFirst().first ?? "Db/in_defense_of_history.sqlite"
        precondition(sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        let db = connection!
        defer { sqlite3_close(db) }
        let v = rows("SELECT * FROM virtual_canvas", db: db).first!
        func number(_ key: String) -> Double { Double(v[key]!)! }
        func size(_ prefix: String, fraction: Bool = false) -> CGSize {
            let suffix = fraction ? "_fraction" : ""
            return CGSize(width: number(prefix + "_width" + suffix),
                          height: number(prefix + "_height" + suffix))
        }
        let virtual = VirtualCanvas(
            size: size("canvas"),
            playAreaRect: CGRect(origin: CGPoint(x: number("play_area_x"), y: number("play_area_y")),
                                 size: size("play_area")),
            pathWidth: number("path" + "_width"), towerSlotSize: size("slot"),
            towerMenuTotalSize: size("tower_menu_total"),
            statsViewSizeFraction: size("stats_view", fraction: true),
            masterControlsSizeFraction: size("master_controls", fraction: true),
            heroBarSizeFraction: size("hero_bar", fraction: true),
            miscViewSizeFraction: size("misc_view", fraction: true))
        let towers = rows("""
            SELECT t.*, tt.tower_type_category AS category, m.rally_point_radius
            FROM tower t JOIN tower_type tt ON tt.id = t.tower_type_id
            LEFT JOIN melee_unit m ON m.tower_id = t.id
            ORDER BY category, tower_level, branch
            """, db: db)
        precondition(towers.count == 24)
        let byName = Dictionary(uniqueKeysWithValues: towers.map {
            ($0["tower_name"]!, Double($0["tower_range"]!)!)
        })
        for row in rows("""
            SELECT t.tower_range, s.min_range, s.max_range
            FROM sim_tower_range s JOIN tower t ON t.id = s.tower_id
            """, db: db) {
            let radius = Double(row["tower_range"]!)!
            precondition(radius >= Double(row["min_range"]!)!)
            precondition(radius <= Double(row["max_range"]!)!)
        }
        let rally = byName["Militia"]!
        near(rally, 330.48)
        // Independent KR proportions catch accidentally reverting the seeds.
        near(byName["Musketmen"]! / rally, 280.0 / 290, tolerance: 0.00002)
        near(byName["Morgan's Sharpshooters"]! / rally, 470.0 / 290, tolerance: 0.00002)
        precondition(byName["Morgan's Sharpshooters"]! > byName["Whitcomb's Rangers"]!)
        precondition(byName["Whitcomb's Rangers"]! > byName["Knowlton's Rangers"]!)
        precondition(byName["Knox's Siege Guns"]! > byName["Mortar Battery"]!)
        precondition(byName["Mortar Battery"]! > byName["Mobile Field Battery"]!)
        for group in Dictionary(grouping: towers, by: { $0["category"]! }).values {
            for tower in group {
                let tier = Int(tower["tower_level"]!)!
                let radius = Double(tower["tower_range"]!)!
                if tier > 1 {
                    let previous = group.first { Int($0["tower_level"]!)! == tier - 1 }!
                    precondition(radius >= Double(previous["tower_range"]!)!)
                }
                if tower["category"] == "Melee" {
                    near(radius, rally)
                    near(Double(tower["rally_point_radius"]!)!, rally)
                }
            }
        }

        let views: [(CGSize, CGRect)] = [
            (CGSize(width: 667, height: 375), CGRect(x: 0, y: 0, width: 667, height: 375)),
            (CGSize(width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 372)),
            (CGSize(width: 393, height: 852), CGRect(x: 0, y: 59, width: 393, height: 759)),
            (CGSize(width: 1194, height: 834), CGRect(x: 0, y: 24, width: 1194, height: 790)),
            (CGSize(width: 1024, height: 600), CGRect(x: 14, y: 21, width: 996, height: 558)),
            (CGSize(width: 2048, height: 1200), CGRect(x: 28, y: 42, width: 1992, height: 1116))
        ]
        for (physical, safe) in views {
            let canvas = RuntimeCanvas(virtualCanvas: virtual,
                                       physicalRect: CGRect(origin: .zero, size: physical),
                                       safeInsetsRect: safe)
            for tower in towers {
                let radius = Double(tower["tower_range"]!)!
                let screenRadius = canvas.rangeRadius(forMapRadius: radius)
                near(screenRadius / canvas.playAreaRect.width, radius / virtual.playAreaRect.width)
                near(screenRadius / canvas.playAreaRect.height, radius / virtual.playAreaRect.height)
                let center = CGPoint(x: safe.midX, y: safe.midY)
                let ring = TowerRangeOverlay.rect(center: center, range: radius, runtimeCanvas: canvas)
                near(ring.midX, center.x)
                near(ring.midY, center.y)
                near(ring.width / 2, screenRadius)
                near(ring.height / ring.width, 0.7)
                // A map-space decision and the same decision after runtime
                // projection must agree, including near the boundary.
                for fraction in [0.999, 1.0, 1.001] {
                    let enemy = TargetCandidate(id: 1, position: Point(radius * fraction, 0),
                                                pathIndex: 0, pathDistance: 0, hp: 1,
                                                morale: 1, isBroken: false)
                    let command = RangedTargetCommand(
                        tower: TowerTargetingContext(slotIndex: 0, position: .zero,
                                                     range: radius, targeting: .first),
                        enemies: [enemy], paths: [])
                    precondition((command.execute() != nil) == (fraction <= 1))
                    let projectedDistance = canvas.rangeRadius(forMapRadius: radius * fraction)
                    precondition((projectedDistance <= screenRadius) == (fraction <= 1))
                }
            }
        }
        print("PASS: 24 tower rows, upgrade / branch roles, militia rally parity, combat boundaries, and 6 RuntimeCanvas layouts.")
    }
}
