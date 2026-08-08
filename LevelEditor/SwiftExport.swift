import Foundation

enum SwiftExport {
    static func code(for d: MapDraft) -> String {
        var out = "    public static let \(identifier(from: d.name)) = LevelBlueprint(\n"
        out += "        name: \"\(d.name)\",\n"
        out += "        startingGold: \(d.startingGold),\n"
        out += "        lives: \(d.lives),\n"

        out += "        roads: [\n"
        for road in d.roads {
            out += "            LevelBlueprint.Road(\"\(road.name)\", [\n"
            let indent = "                "
            var line = indent
            for cp in road.points {
                let p = CanvasSpec.toDesign(cp)
                let piece = "Point(\(num(p.x)), \(num(p.y))), "
                if line.count + piece.count > 96, line != indent {
                    out += rtrim(line) + "\n"
                    line = indent
                }
                line += piece
            }
            if line != indent {
                out += rtrim(line) + "\n"
            }
            out += "            ]),\n"
        }
        out += "        ],\n"

        out += "        slots: [\n"
        for (i, cp) in d.slots.enumerated() {
            let p = CanvasSpec.toDesign(cp)
            out += "            Point(\(num(p.x)), \(num(p.y))),   // \(i)\n"
        }
        out += "        ],\n"

        out += "        waves: [\n"
        for w in d.waves {
            out += "            .init(breather: \(num(w.breather)), lines: [\n"
            for l in w.lines {
                var args = "\(foeCase(l.foe)), count: \(l.count), every: \(num(l.every))"
                if l.delay != 0 { args += ", delay: \(num(l.delay))" }
                if l.road != 0 { args += ", road: \(l.road)" }
                out += "                .init(\(args)),\n"
            }
            out += "            ]),\n"
        }
        out += "        ]"

        if !d.intendedSolution.isEmpty {
            out += ",\n        intendedSolution: [\n"
            for s in d.intendedSolution.sorted(by: { $0.at < $1.at }) {
                let order: String
                if s.kind == "place" {
                    order = ".place(\(emplacementCase(s.emplacement)), slot: \(s.slot))"
                } else {
                    order = ".upgrade(slot: \(s.slot))"
                }
                out += "            .init(at: \(num(s.at)), \(order)),\n"
            }
            out += "        ]\n"
        } else {
            out += "\n"
        }
        out += "    )\n"
        return out
    }

    static func rtrim(_ s: String) -> String {
        String(s.reversed().drop { $0 == " " }.reversed())
    }

    static func num(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        var s = String(format: "%.2f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    static func foeCase(_ raw: String) -> String {
        if let foe = Foe(rawValue: raw) { return ".\(foe)" }
        return ".loyalistMilitia /* unknown foe: \(raw) */"
    }

    static func emplacementCase(_ raw: String?) -> String {
        if let raw, let e = Emplacement(rawValue: raw) { return ".\(e)" }
        return ".minutemanPost /* unknown emplacement */"
    }

    static func identifier(from name: String) -> String {
        let words = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard let first = words.first else { return "untitledMap" }
        var ident = first.lowercased() + words.dropFirst().map(\.capitalized).joined()
        if let c = ident.first, c.isNumber { ident = "level" + ident }
        return ident
    }
}
