// Palette.swift
// Shared design-space transform and the schematic color language used by
// both the editor canvas and the playtest canvas.
import SwiftUI

struct DesignTransform {
    var scale: CGFloat
    var offset: CGPoint
    var space: CGSize

    init(fitting size: CGSize, space: CGSize) {
        self.space = space
        scale = min(size.width / space.width, size.height / space.height)
        offset = CGPoint(
            x: (size.width - space.width * scale) / 2,
            y: (size.height - space.height * scale) / 2
        )
    }

    init(scale: CGFloat, space: CGSize) {
        self.scale = scale
        self.offset = .zero
        self.space = space
    }

    func view(_ p: Point) -> CGPoint {
        CGPoint(x: p.x * scale + offset.x, y: p.y * scale + offset.y)
    }

    func view(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * scale + offset.x, y: r.minY * scale + offset.y,
               width: r.width * scale, height: r.height * scale)
    }

    func design(_ p: CGPoint) -> Point {
        Point(Double((p.x - offset.x) / scale), Double((p.y - offset.y) / scale))
    }

    var frame: CGRect {
        CGRect(x: offset.x, y: offset.y,
               width: space.width * scale, height: space.height * scale)
    }
}

enum Palette {
    static let towerColors: [Emplacement: Color] = [
        .minutemanPost: .blue,
        .longRifles: .indigo,
        .fieldBattery: .orange,
        .libertyPole: .purple,
    ]

    static let foeColors: [Foe: Color] = [
        .loyalistMilitia: Color(white: 0.62),
        .regimentalDrummer: .cyan,
        .redcoatRegular: .red,
        .lightInfantry: .pink,
        .hessianJager: .green,
        .hessianFusilier: Color(red: 0.55, green: 0.05, blue: 0.15),
        .nativeWarrior: Color(red: 0.85, green: 0.55, blue: 0.1),
        .highlander: Color(red: 0.05, green: 0.45, blue: 0.3),
        .lightDragoon: .yellow,
        .spy: Color(white: 0.2),
        .grenadier: Color(red: 0.45, green: 0.0, blue: 0.05),
        .royalArtillery: .brown,
        .mountedOfficer: Color(red: 0.9, green: 0.75, blue: 0.2),
        .footGuards: Color(red: 0.85, green: 0.1, blue: 0.25),
    ]

    static let mapBackground = Color(red: 0.10, green: 0.13, blue: 0.10)
    static let roadEdge = Color(red: 0.25, green: 0.2, blue: 0.13)
    static let roadFill = Color(red: 0.45, green: 0.37, blue: 0.24)

    static func color(forFoeID id: UUID) -> Color {
        if let foe = Foe.allCases.first(where: { $0.id == id }) {
            return foeColors[foe] ?? .white
        }
        return .white
    }

    static func color(forTowerID id: UUID) -> Color {
        if let e = Emplacement.allCases.first(where: { $0.id == id }) {
            return towerColors[e] ?? .white
        }
        return .white
    }
}
