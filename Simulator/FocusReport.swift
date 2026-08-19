import Foundation

/// One focus value (e.g. range = 137) and everything measured at it.
///
/// Every statistic here is a mean, never a percentile. A permutation's win
/// rate is the share of its seeds that won, and with deterministic damage
/// that share is always exactly 0 or 1 — so percentiles of it are also 0 or
/// 1 and carry no information. The mean of a 0/1 sample is the fraction of
/// permutations that won, which is the quantity worth plotting.
struct FocusBucket {
    var value: Double
    var label: String
    var n = 0
    var winSum = 0.0
    var livesFractionSum = 0.0
    var leakedSum = 0.0
    var zeroWin = 0

    var winMean: Double { n == 0 ? 0 : winSum / Double(n) }
    var livesFraction: Double { n == 0 ? 0 : livesFractionSum / Double(n) }
    var meanLeaked: Double { n == 0 ? 0 : leakedSum / Double(n) }
    var zeroShare: Double { n == 0 ? 0 : Double(zeroWin) / Double(n) }

    /// Half-width of the 95% confidence interval on `winMean`, treating each
    /// permutation as one Bernoulli draw. Anything smaller than this is
    /// sampling noise, not a real change in the curve.
    var winMarginOfError: Double {
        guard n > 1 else { return 0 }
        let p = winMean
        return 1.96 * (p * (1 - p) / Double(n)).squareRoot()
    }
}

/// The single-variable focus study report for one sweep: per-value
/// aggregates as CSV and charts as HTML.
struct FocusReport {
    let focus: SweepFocus
    let space: SweepSpace

    init(focus: SweepFocus, space: SweepSpace) {
        self.focus = focus
        self.space = space
    }

    let prettyNames: [String: String] = [
        "range": "Range",
        "rof": "Fire interval",
        "growth": "Upgrade cost growth",
        "splash": "Blast radius",
        "falloff": "Blast falloff",
        "projspeed": "Projectile speed",
        "money": "Starting money",
        "lives": "Starting lives",
        "enemyspeed": "Enemy speed bracket",
        "enemyhp": "Enemy HP bracket",
        "enemybounty": "Enemy bounty bracket",
        "meleehp": "Melee unit HP bracket",
        "meleedamage": "Melee unit damage bracket",
        "curve": "Wave curve",
        "mix": "Wave mix",
        "spacing": "Spawn spacing",
    ]

    let units: [String: String] = [
        "range": "canonical units",
        "rof": "seconds",
        "growth": "× per level",
        "splash": "canonical units",
        "falloff": "exponent",
        "projspeed": "canonical units/s",
        "money": "gold",
        "lives": "lives",
        "enemyspeed": "bracket position 0–1",
        "enemyhp": "bracket position 0–1",
        "enemybounty": "bracket position 0–1",
        "meleehp": "bracket position 0–1",
        "meleedamage": "bracket position 0–1",
    ]

    func value(of perm: SweepPermutation) -> (num: Double, label: String)? {
        func fmt(_ v: Double) -> String {
            v == v.rounded() ? String(Int(v)) : String(format: "%g", v)
        }
        switch focus.stat {
        case "range": return perm.rangeByKind[focus.kind].map { ($0, fmt($0)) }
        case "rof": return perm.rofByKind[focus.kind].map { ($0, fmt($0)) }
        case "growth": return perm.upgradeGrowth[focus.kind].map { ($0, fmt($0)) }
        case "splash": return perm.splashByKind[focus.kind].map { ($0, fmt($0)) }
        case "falloff": return perm.falloffByKind[focus.kind].map { ($0, fmt($0)) }
        case "projspeed": return perm.projSpeedByKind[focus.kind].map { ($0, fmt($0)) }
        case "money": return (Double(perm.money), String(perm.money))
        case "lives": return (Double(perm.lives), String(perm.lives))
        case "enemyspeed": return (perm.enemySpeedBracketPosition, fmt(perm.enemySpeedBracketPosition))
        case "enemyhp": return (perm.enemyHpBracketPosition, fmt(perm.enemyHpBracketPosition))
        case "enemybounty": return (perm.enemyBountyBracketPosition, fmt(perm.enemyBountyBracketPosition))
        case "meleehp": return (perm.meleeHpBracketPosition, fmt(perm.meleeHpBracketPosition))
        case "meleedamage": return (perm.meleeDamageBracketPosition, fmt(perm.meleeDamageBracketPosition))
        case "curve": return space.curves.firstIndex(of: perm.curve).map { (Double($0), perm.curve) }
        case "mix": return space.mixes.firstIndex(of: perm.mix).map { (Double($0), perm.mix) }
        case "spacing": return space.spacings.firstIndex(of: perm.spacing).map { (Double($0), perm.spacing) }
        default: return nil
        }
    }

    /// The identity of a permutation's *other* variables, recovered from its
    /// grid index. The paired design lays out index as
    /// `lo + (f + hi * count) * place`, so stripping `f` leaves a key that is
    /// identical across every focus value — which is what lets the report
    /// compare the same opponent under different focus values.
    func otherSampleKey(index: Int, place: Int, count: Int) -> Int {
        let lo = index % place
        let hi = index / place / count
        return lo + hi * place
    }

    struct Curve {
        var name: String
        var points: [Double]
    }

    func emit(rows: [SweepRow], sweepOut: String) throws {
        var byLabel: [String: FocusBucket] = [:]
        for row in rows {
            guard let (num, label) = value(of: row.perm) else { continue }
            var b = byLabel[label] ?? FocusBucket(value: num, label: label)
            b.n += 1
            b.winSum += row.winRate
            b.livesFractionSum += row.livesP50 / Double(max(1, row.perm.lives))
            b.leakedSum += row.meanLeaked
            if row.winRate == 0 { b.zeroWin += 1 }
            byLabel[label] = b
        }
        let buckets = byLabel.values.sorted { $0.value < $1.value }
        guard !buckets.isEmpty else {
            print("focus: no rows to aggregate")
            return
        }

        let terciles = tercileCurves(rows: rows, buckets: buckets)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let variable = focus.label.replacingOccurrences(of: ":", with: "-")
        let dir: String
        if space.grids.reportDir.isEmpty {
            dir = (sweepOut as NSString).deletingLastPathComponent
        } else {
            dir = space.grids.reportDir
        }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let stem = (dir as NSString).appendingPathComponent("focus_\(variable)_\(df.string(from: Date()))")
        let csvPath = stem + ".csv"
        let htmlPath = stem + ".html"

        var csv = "focus_value,label,perms,win_mean,win_moe_95,zero_win_share,"
            + "lives_fraction,mean_leaked"
        for c in terciles { csv += ",win_\(c.name.replacingOccurrences(of: " ", with: "_"))" }
        csv += "\n"
        for (i, b) in buckets.enumerated() {
            csv += "\(b.value),\(b.label),\(b.n),"
                + String(format: "%.4f,%.4f,%.4f,%.4f,%.4f",
                         b.winMean, b.winMarginOfError, b.zeroShare,
                         b.livesFraction, b.meanLeaked)
            for c in terciles { csv += String(format: ",%.4f", c.points[i]) }
            csv += "\n"
        }
        try csv.write(toFile: csvPath, atomically: true, encoding: .utf8)

        let html = try renderHTML(buckets: buckets, terciles: terciles,
                                  rows: rows, csvPath: csvPath)
        try html.write(toFile: htmlPath, atomically: true, encoding: .utf8)

        let pretty = prettyNames[focus.stat] ?? focus.stat
        let kindNote = focus.kind.isEmpty ? "" : " (\(focus.kind))"
        func pct(_ v: Double) -> String { String(format: "%3.0f%%", v * 100) }
        func bar(_ v: Double, width: Int = 12) -> String {
            let filled = max(0, min(width, Int((v * Double(width)).rounded())))
            return String(repeating: "█", count: filled) + String(repeating: "·", count: width - filled)
        }
        let maxWin = buckets.map(\.winMean).max() ?? 0
        let knee = buckets.first { $0.winMean >= maxWin - 0.01 }
        print("\n── focus: \(pretty)\(kindNote) — \(space.fixedInputs.levelName) ──────────")
        print("  value      perms   win mean  ±95%    lives kept        leaked")
        for b in buckets {
            let marker = b.label == knee?.label ? "  ← plateau starts" : ""
            print("  \(b.label.padding(toLength: 9, withPad: " ", startingAt: 0))"
                + "\(String(b.n).padding(toLength: 8, withPad: " ", startingAt: 0))"
                + "\(pct(b.winMean))     ±\(String(format: "%.1f", b.winMarginOfError * 100))%"
                + "   \(bar(b.livesFraction)) \(pct(b.livesFraction))"
                + "  \(String(format: "%5.1f", b.meanLeaked))\(marker)")
        }
        print("""
          aggregates: \(csvPath)
          charts:     \(htmlPath)  (open in a browser)
        ──────────────────────────────────────────────────────
        """)
    }

    /// Split the other-variable samples into thirds by how well they do
    /// overall, then re-plot the focus curve within each third.
    ///
    /// The paired design guarantees every third meets every focus value, so
    /// the horizontal distance between the three curves is the interaction
    /// between the focus variable and everything else: curves on top of one
    /// another mean the focus answer is independent of the rest of the
    /// design; curves far apart mean the answer moves when the rest moves.
    func tercileCurves(rows: [SweepRow], buckets: [FocusBucket]) -> [Curve] {
        guard let (place, count) = space.focusPlacement(stat: focus.stat, kind: focus.kind),
              count > 1, buckets.count > 1 else { return [] }
        let slotOf = Dictionary(uniqueKeysWithValues: buckets.enumerated().map { ($0.element.label, $0.offset) })

        var byOther: [Int: [Double?]] = [:]
        for row in rows {
            guard let (_, label) = value(of: row.perm),
                  let slot = slotOf[label] else { continue }
            let key = otherSampleKey(index: row.perm.index, place: place, count: count)
            var series = byOther[key] ?? [Double?](repeating: nil, count: buckets.count)
            series[slot] = row.winRate
            byOther[key] = series
        }
        let complete = byOther.values.filter { series in series.allSatisfy { $0 != nil } }
            .map { $0.map { $0! } }
        guard complete.count >= 6 else { return [] }

        let ranked = complete.sorted {
            $0.reduce(0, +) / Double($0.count) < $1.reduce(0, +) / Double($1.count)
        }
        let cut = ranked.count / 3
        let groups: [(String, ArraySlice<[Double]>)] = [
            ("hardest third", ranked[0..<cut]),
            ("middle third", ranked[cut..<(ranked.count - cut)]),
            ("easiest third", ranked[(ranked.count - cut)...]),
        ]
        return groups.map { name, slice in
            var points = [Double](repeating: 0, count: buckets.count)
            for series in slice {
                for i in points.indices { points[i] += series[i] }
            }
            let d = Double(max(1, slice.count))
            return Curve(name: name, points: points.map { $0 / d })
        }
    }

    func faviconTag() -> String {
        let candidates = [
            "Simulator/Images/favicon.ico",
            "Images/favicon.ico",
            ("~/projects/td/in-defense-of-history/Simulator/Images/favicon.ico" as NSString).expandingTildeInPath,
        ]
        for path in candidates {
            guard let data = FileManager.default.contents(atPath: path) else { continue }
            return "<link rel=\"icon\" type=\"image/x-icon\" href=\"data:image/x-icon;base64,\(data.base64EncodedString())\">"
        }
        FileHandle.standardError.write(Data("  note: Simulator/Images/favicon.ico not found — report has no favicon\n".utf8))
        return ""
    }

    func renderHTML(buckets: [FocusBucket], terciles: [Curve],
                    rows: [SweepRow], csvPath: String) throws -> String {
        func r4(_ v: Double) -> Double { (v * 10000).rounded() / 10000 }
        var values: [[String: Any]] = []
        for b in buckets {
            values.append([
                "value": b.value,
                "label": b.label,
                "n": b.n,
                "mean": r4(b.winMean),
                "moe": r4(b.winMarginOfError),
                "zero": r4(b.zeroShare),
                "lives": r4(b.livesFraction),
                "leaked": r4(b.meanLeaked),
            ])
        }
        let pretty = prettyNames[focus.stat] ?? focus.stat
        let kindNote = focus.kind.isEmpty ? "" : " — \(focus.kind) tower"
        let unit = units[focus.stat] ?? ""
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let payload: [String: Any] = [
            "focusPretty": pretty + kindNote,
            "unit": unit,
            "level": space.fixedInputs.levelName,
            "categorical": ["curve", "mix", "spacing"].contains(focus.stat),
            "seedsPerPerm": space.grids.seedsPerPermutation,
            "totalRows": rows.count,
            "values": values,
            "terciles": terciles.map { ["name": $0.name, "points": $0.points.map(r4)] },
        ]
        let json = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let jsonString = String(data: json, encoding: .utf8) ?? "{}"

        let sub = "\(buckets.count) focus values × \(buckets.map(\.n).min() ?? 0) paired permutation samples "
            + "of every other variable · \(rows.count) sweep rows · ≤\(space.grids.seedsPerPermutation) seeds each"
        return htmlTemplate
            .replacingOccurrences(of: "__FAVICON__", with: faviconTag())
            .replacingOccurrences(of: "__TITLE__", with: "\(pretty)\(kindNote) — \(space.fixedInputs.levelName)")
            .replacingOccurrences(of: "__SUB__", with: sub)
            .replacingOccurrences(of: "__FOOT__", with: "Generated \(df.string(from: Date())) · aggregates: \(csvPath)")
            .replacingOccurrences(of: "__PAYLOAD__", with: jsonString)
    }

    var htmlTemplate: String { #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
__FAVICON__
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  :root { color-scheme: light dark; }
  body {
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    padding: 28px 20px 48px;
  }
  .viz-root {
    max-width: 1060px; margin: 0 auto;
    color: var(--ink);
    --surface: #fcfcfb; --ink: #0b0b0b; --ink2: #52514e;
    --muted: #898781; --grid: #e1e0d9; --axis: #c3c2b7;
    --border: rgba(11,11,11,0.10);
    --s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a;
  }
  @media (prefers-color-scheme: dark) {
    :root:where(:not([data-theme="light"])) .viz-root {
      --surface: #1a1a19; --ink: #ffffff; --ink2: #c3c2b7;
      --muted: #898781; --grid: #2c2c2a; --axis: #383835;
      --border: rgba(255,255,255,0.10);
      --s1: #3987e5; --s2: #d95926; --s3: #199e70;
    }
  }
  :root[data-theme="dark"] .viz-root {
    --surface: #1a1a19; --ink: #ffffff; --ink2: #c3c2b7;
    --muted: #898781; --grid: #2c2c2a; --axis: #383835;
    --border: rgba(255,255,255,0.10);
    --s1: #3987e5; --s2: #d95926; --s3: #199e70;
  }
  body { background: #f9f9f7; }
  @media (prefers-color-scheme: dark) {
    :root:where(:not([data-theme="light"])) body { background: #0d0d0d; }
  }
  :root[data-theme="dark"] body { background: #0d0d0d; }
  header h1 { font-size: 22px; font-weight: 650; letter-spacing: -0.01em; }
  header .sub { color: var(--ink2); font-size: 13px; margin-top: 5px; }
  .kpis { display: flex; flex-wrap: wrap; gap: 12px; margin: 20px 0; }
  .tile {
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
    padding: 14px 18px; min-width: 150px; flex: 0 1 auto;
  }
  .tile .label { font-size: 12px; color: var(--ink2); }
  .tile .value { font-size: 26px; font-weight: 600; margin-top: 4px; }
  .tile.hero .value { font-size: 48px; }
  .tile .note { font-size: 11px; color: var(--muted); margin-top: 3px; }
  .card {
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
    padding: 18px 18px 12px; margin-bottom: 16px;
  }
  .card h2 { font-size: 15px; font-weight: 600; }
  .chart-sub { font-size: 12px; color: var(--ink2); margin-top: 3px; margin-bottom: 8px; }
  .chart-why { font-size: 12px; color: var(--muted); margin-top: 2px; margin-bottom: 8px; }
  .chart { position: relative; }
  .legend { display: flex; flex-wrap: wrap; gap: 14px; font-size: 12px; color: var(--ink2); margin: 6px 0 4px; }
  .legend .item { display: inline-flex; align-items: center; gap: 6px; }
  .legend .linekey { width: 16px; height: 2px; border-radius: 1px; display: inline-block; }
  .legend .swatch { width: 11px; height: 11px; border-radius: 3px; display: inline-block; }
  .tooltip {
    position: fixed; z-index: 10; pointer-events: none;
    background: var(--surface); color: var(--ink);
    border: 1px solid var(--border); border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.14);
    padding: 9px 12px; font-size: 12px; max-width: 280px;
  }
  .tooltip .tt-title { font-weight: 600; margin-bottom: 5px; }
  .tooltip .tt-row { display: flex; align-items: baseline; gap: 8px; margin-top: 2px; }
  .tooltip .tt-key { width: 12px; height: 2px; border-radius: 1px; flex: none; align-self: center; }
  .tooltip .tt-val { font-weight: 600; font-variant-numeric: tabular-nums; }
  .tooltip .tt-name { color: var(--ink2); }
  .tablewrap { overflow-x: auto; max-height: 460px; }
  table { border-collapse: collapse; font-size: 12px; width: 100%; }
  th, td { text-align: right; padding: 6px 10px; font-variant-numeric: tabular-nums; white-space: nowrap; }
  th:first-child, td:first-child { text-align: left; }
  th { color: var(--ink2); font-weight: 600; border-bottom: 1px solid var(--axis);
       position: sticky; top: 0; background: var(--surface); }
  td { border-bottom: 1px solid var(--grid); color: var(--ink); }
  footer { color: var(--muted); font-size: 11px; margin-top: 20px; }
  svg text { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; }
</style>
</head>
<body>
<div class="viz-root">
  <header>
    <h1>__TITLE__</h1>
    <p class="sub">__SUB__</p>
  </header>
  <section class="kpis" id="kpis"></section>
  <section class="card">
    <h2>Win rate</h2>
    <p class="chart-sub">Share of sampled permutations the reference player wins at each value, with a 95% confidence band.</p>
    <p class="chart-why">Why this chart: a permutation either wins or it does not, so the mean is the only summary that carries information — it is literally the fraction that won. Read the flat zero region as impossible, the steep part as the tuning window, and the flat top as the value no longer mattering. Wiggles smaller than the band are sampling noise.</p>
    <div class="chart" id="winCurve"></div>
  </section>
  <section class="card">
    <h2>Margin of victory</h2>
    <p class="chart-sub">Lives kept at the end, as a share of starting lives, against the same win rate.</p>
    <p class="chart-why">Why this chart: win rate saturates — once nearly everything wins it can no longer tell a comfortable value from a marginal one. Lives kept keeps resolving past that point. Where the two curves separate, the player is winning by a hair.</p>
    <div class="legend" id="marginLegend"></div>
    <div class="chart" id="margin"></div>
  </section>
  <section class="card">
    <h2>Does the answer hold when everything else changes?</h2>
    <p class="chart-sub">The same curve, computed separately for the hardest, middle and easiest third of the other-variable samples. Every third meets every value — the design is paired.</p>
    <p class="chart-why">Why this chart: a single averaged curve hides whether the answer is stable. If the three curves are horizontally close, this variable can be tuned on its own. If they are far apart, the right value depends on what the rest of the design is doing, and a single recommended number is a fiction.</p>
    <div class="legend" id="tercileLegend"></div>
    <div class="chart" id="terciles"></div>
  </section>
  <section class="card">
    <h2>Data table</h2>
    <div class="tablewrap" id="table"></div>
  </section>
  <footer id="foot">__FOOT__</footer>
</div>
<div id="tooltip" class="tooltip" hidden></div>
<script>
"use strict";
const DATA = __PAYLOAD__;
const NS = "http://www.w3.org/2000/svg";

function isDark() {
  const t = document.documentElement.dataset.theme;
  if (t === "dark") return true;
  if (t === "light") return false;
  return matchMedia("(prefers-color-scheme: dark)").matches;
}

function colors() {
  return isDark() ? {
    ink: "#ffffff", ink2: "#c3c2b7", muted: "#898781", grid: "#2c2c2a",
    axis: "#383835", surface: "#1a1a19", s1: "#3987e5", s2: "#d95926", s3: "#199e70"
  } : {
    ink: "#0b0b0b", ink2: "#52514e", muted: "#898781", grid: "#e1e0d9",
    axis: "#c3c2b7", surface: "#fcfcfb", s1: "#2a78d6", s2: "#eb6834", s3: "#1baf7a"
  };
}

function el(tag, attrs, parent) {
  const e = document.createElementNS(NS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
function textEl(parent, x, y, str, fill, size, anchor, weight) {
  const t = el("text", { x, y, fill, "font-size": size || 11, "text-anchor": anchor || "start" }, parent);
  if (weight) t.setAttribute("font-weight", weight);
  t.textContent = str;
  return t;
}
function pct(v, digits) { return (v * 100).toFixed(digits === undefined ? 0 : digits) + "%"; }

const tooltip = document.getElementById("tooltip");
function showTooltip(evt, title, rows) {
  tooltip.replaceChildren();
  const t = document.createElement("div");
  t.className = "tt-title";
  t.textContent = title;
  tooltip.appendChild(t);
  for (const r of rows) {
    const row = document.createElement("div");
    row.className = "tt-row";
    if (r.key) {
      const k = document.createElement("span");
      k.className = "tt-key";
      k.style.background = r.key;
      row.appendChild(k);
    }
    const v = document.createElement("span");
    v.className = "tt-val";
    v.textContent = r.value;
    row.appendChild(v);
    const n = document.createElement("span");
    n.className = "tt-name";
    n.textContent = r.name;
    row.appendChild(n);
    tooltip.appendChild(row);
  }
  tooltip.hidden = false;
  positionTooltip(evt);
}
function positionTooltip(evt) {
  const pad = 14;
  const r = tooltip.getBoundingClientRect();
  let x = evt.clientX + pad, y = evt.clientY + pad;
  if (x + r.width > innerWidth - 8) x = evt.clientX - r.width - pad;
  if (y + r.height > innerHeight - 8) y = evt.clientY - r.height - pad;
  tooltip.style.left = x + "px";
  tooltip.style.top = y + "px";
}
function hideTooltip() { tooltip.hidden = true; }

function legendInto(id, items) {
  const box = document.getElementById(id);
  box.replaceChildren();
  for (const it of items) {
    const item = document.createElement("span");
    item.className = "item";
    const sw = document.createElement("span");
    sw.className = it.box ? "swatch" : "linekey";
    sw.style.background = it.color;
    item.appendChild(sw);
    item.appendChild(document.createTextNode(it.name));
    box.appendChild(item);
  }
}

function geometry(container, height) {
  const w = Math.max(420, container.clientWidth);
  return { w, h: height, ml: 44, mr: 14, mt: 12, mb: 26 };
}
function slotX(g, i, n) { return n === 1 ? g.ml : g.ml + (i + 0.5) * ((g.w - g.ml - g.mr) / n); }
function slotW(g, n) { return (g.w - g.ml - g.mr) / n; }

function xTicks(svg, g, C) {
  const n = DATA.values.length;
  const maxTicks = Math.max(3, Math.floor((g.w - g.ml - g.mr) / 56));
  const every = Math.ceil(n / maxTicks);
  for (let i = 0; i < n; i++) {
    if (i % every !== 0 && i !== n - 1) continue;
    textEl(svg, slotX(g, i, n), g.h - g.mb + 16, DATA.values[i].label, C.muted, 11, "middle");
  }
}

function yAxisPct(svg, g, C, ticks) {
  for (const v of ticks) {
    const y = g.mt + (1 - v) * (g.h - g.mt - g.mb);
    el("line", { x1: g.ml, x2: g.w - g.mr, y1: y, y2: y, stroke: C.grid, "stroke-width": 1 }, svg);
    textEl(svg, g.ml - 6, y + 4, pct(v), C.muted, 10, "end");
  }
  el("line", { x1: g.ml, x2: g.w - g.mr, y1: g.h - g.mb, y2: g.h - g.mb, stroke: C.axis, "stroke-width": 1 }, svg);
}

function linePath(pts) {
  return pts.map((p, i) => (i === 0 ? "M" : "L") + p[0].toFixed(1) + "," + p[1].toFixed(1)).join(" ");
}

function crosshair(svg, g, n, box, build) {
  const cross = el("line", { y1: g.mt, y2: g.h - g.mb, stroke: C0.axis, "stroke-width": 1, visibility: "hidden" }, svg);
  const hit = el("rect", { x: g.ml, y: 0, width: g.w - g.ml - g.mr, height: g.h, fill: "transparent" }, svg);
  hit.addEventListener("pointermove", evt => {
    const rect = svg.getBoundingClientRect();
    let i = Math.round((evt.clientX - rect.left - g.ml) / slotW(g, n) - 0.5);
    i = Math.max(0, Math.min(n - 1, i));
    const x = slotX(g, i, n);
    cross.setAttribute("x1", x); cross.setAttribute("x2", x);
    cross.setAttribute("visibility", "visible");
    showTooltip(evt, DATA.focusPretty + " " + DATA.values[i].label, build(i));
  });
  hit.addEventListener("pointerleave", () => { cross.setAttribute("visibility", "hidden"); hideTooltip(); });
}

let C0 = colors();

function renderWinCurve() {
  const box = document.getElementById("winCurve");
  box.replaceChildren();
  const C = C0;
  const g = geometry(box, 300);
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  const y = v => g.mt + (1 - Math.max(0, Math.min(1, v))) * (g.h - g.mt - g.mb);
  yAxisPct(svg, g, C, [0, 0.25, 0.5, 0.75, 1]);
  const px = i => slotX(g, i, n);
  const band = DATA.values.map((d, i) => [px(i), y(d.mean + d.moe)])
    .concat(DATA.values.map((d, i) => [px(n - 1 - i), y(DATA.values[n - 1 - i].mean - DATA.values[n - 1 - i].moe)]));
  el("path", { d: linePath(band) + " Z", fill: C.s1, opacity: 0.18 }, svg);
  el("path", { d: linePath(DATA.values.map((d, i) => [px(i), y(d.mean)])),
               fill: "none", stroke: C.s1, "stroke-width": 2,
               "stroke-linecap": "round", "stroke-linejoin": "round" }, svg);
  if (n <= 40) {
    DATA.values.forEach((d, i) => {
      el("circle", { cx: px(i), cy: y(d.mean), r: 4, fill: C.s1, stroke: C.surface, "stroke-width": 2 }, svg);
    });
  }
  xTicks(svg, g, C);
  crosshair(svg, g, n, box, i => {
    const d = DATA.values[i];
    return [
      { name: "win rate", value: pct(d.mean, 1), key: C.s1 },
      { name: "95% band", value: "±" + pct(d.moe, 1) },
      { name: "never won", value: pct(d.zero, 1) + " of permutations" },
      { name: "permutations", value: String(d.n) }
    ];
  });
}

function renderMargin() {
  const box = document.getElementById("margin");
  box.replaceChildren();
  const C = C0;
  legendInto("marginLegend", [
    { name: "Win rate", color: C.s1 },
    { name: "Lives kept (share of starting lives)", color: C.s2 }
  ]);
  const g = geometry(box, 240);
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  const y = v => g.mt + (1 - Math.max(0, Math.min(1, v))) * (g.h - g.mt - g.mb);
  yAxisPct(svg, g, C, [0, 0.5, 1]);
  for (const s of [{ key: "mean", color: C.s1 }, { key: "lives", color: C.s2 }]) {
    el("path", { d: linePath(DATA.values.map((d, i) => [slotX(g, i, n), y(d[s.key])])),
                 fill: "none", stroke: s.color, "stroke-width": 2,
                 "stroke-linecap": "round", "stroke-linejoin": "round" }, svg);
  }
  xTicks(svg, g, C);
  crosshair(svg, g, n, box, i => {
    const d = DATA.values[i];
    return [
      { name: "win rate", value: pct(d.mean, 1), key: C.s1 },
      { name: "lives kept", value: pct(d.lives, 1), key: C.s2 },
      { name: "enemies leaked", value: d.leaked.toFixed(1) + " per run" }
    ];
  });
}

function renderTerciles() {
  const box = document.getElementById("terciles");
  box.replaceChildren();
  const C = C0;
  if (!DATA.terciles.length) {
    const p = document.createElement("p");
    p.className = "chart-sub";
    p.textContent = "Not enough complete paired samples to split into thirds.";
    box.appendChild(p);
    document.getElementById("tercileLegend").replaceChildren();
    return;
  }
  const palette = [C.s2, C.s1, C.s3];
  legendInto("tercileLegend", DATA.terciles.map((t, k) => ({ name: t.name, color: palette[k] })));
  const g = geometry(box, 260);
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  const y = v => g.mt + (1 - Math.max(0, Math.min(1, v))) * (g.h - g.mt - g.mb);
  yAxisPct(svg, g, C, [0, 0.5, 1]);
  DATA.terciles.forEach((t, k) => {
    el("path", { d: linePath(t.points.map((v, i) => [slotX(g, i, n), y(v)])),
                 fill: "none", stroke: palette[k], "stroke-width": 2,
                 "stroke-linecap": "round", "stroke-linejoin": "round" }, svg);
  });
  xTicks(svg, g, C);
  crosshair(svg, g, n, box, i =>
    DATA.terciles.map((t, k) => ({ name: t.name, value: pct(t.points[i], 1), key: palette[k] })));
}

function renderKpis() {
  const box = document.getElementById("kpis");
  box.replaceChildren();
  const V = DATA.values;
  function tile(label, value, note, hero) {
    const t = document.createElement("div");
    t.className = "tile" + (hero ? " hero" : "");
    const l = document.createElement("div"); l.className = "label"; l.textContent = label;
    const v = document.createElement("div"); v.className = "value"; v.textContent = value;
    t.appendChild(l); t.appendChild(v);
    if (note) { const nt = document.createElement("div"); nt.className = "note"; nt.textContent = note; t.appendChild(nt); }
    box.appendChild(t);
  }
  const maxWin = Math.max(...V.map(d => d.mean));
  const knee = V.find(d => d.mean >= maxWin - 0.01);
  const half = V.find(d => d.mean >= 0.5);
  const dead = V.filter(d => d.mean === 0);
  tile("Plateau starts at", knee ? knee.label : "—",
       (DATA.unit ? DATA.unit + " · " : "") + "first value within 1 point of the best", true);
  tile("Best win rate", pct(maxWin, 1), "highest value on the grid");
  tile("Crosses 50% at", half ? half.label : "never", "coin-flip difficulty");
  tile("Never wins", dead.length ? dead.length + " values" : "none",
       dead.length ? "up to " + dead[dead.length - 1].label : "every value wins sometimes");
}

function renderTable() {
  const box = document.getElementById("table");
  box.replaceChildren();
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const hr = document.createElement("tr");
  const heads = ["Value", "Perms", "Win rate", "±95%", "Never won", "Lives kept", "Leaked"]
    .concat(DATA.terciles.map(t => t.name));
  for (const h of heads) {
    const th = document.createElement("th");
    th.textContent = h;
    hr.appendChild(th);
  }
  thead.appendChild(hr);
  table.appendChild(thead);
  const tbody = document.createElement("tbody");
  DATA.values.forEach((d, i) => {
    const tr = document.createElement("tr");
    const cells = [d.label, d.n, pct(d.mean, 1), "±" + pct(d.moe, 1), pct(d.zero, 1),
                   pct(d.lives, 1), d.leaked.toFixed(1)]
      .concat(DATA.terciles.map(t => pct(t.points[i], 1)));
    for (const v of cells) {
      const td = document.createElement("td");
      td.textContent = String(v);
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  });
  table.appendChild(tbody);
  box.appendChild(table);
}

function renderAll() {
  C0 = colors();
  renderKpis();
  renderWinCurve();
  renderMargin();
  renderTerciles();
  renderTable();
}
renderAll();
addEventListener("resize", renderAll);
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", renderAll);
new MutationObserver(renderAll).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
</script>
</body>
</html>
"""#
    }
}
