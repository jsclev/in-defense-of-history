import Foundation

struct FocusBucket {
    var value: Double
    var label: String
    var wins: [Double] = []
    var unwinnable = 0
    var struggle = 0
    var band = 0
    var comfortable = 0
    var trivial = 0
    var naiveClearSum = 0.0
    var greedyClearSum = 0.0
    var histogram = [Int](repeating: 0, count: 10)

    var n: Int { wins.count }
    var winMean: Double { wins.isEmpty ? 0 : wins.reduce(0, +) / Double(wins.count) }
    var bandShare: Double { n == 0 ? 0 : Double(band) / Double(n) }
    var naiveClear: Double { n == 0 ? 0 : naiveClearSum / Double(n) }
    var greedyClear: Double { n == 0 ? 0 : greedyClearSum / Double(n) }

    func winPercentile(_ p: Double) -> Double {
        guard !wins.isEmpty else { return 0 }
        let idx = p / 100 * Double(wins.count - 1)
        let lo = Int(idx.rounded(.down))
        let hi = Int(idx.rounded(.up))
        let frac = idx - Double(lo)
        return wins[lo] * (1 - frac) + wins[hi] * frac
    }
}

enum FocusReport {
    static let prettyNames: [String: String] = [
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

    static let units: [String: String] = [
        "range": "design units",
        "rof": "seconds",
        "growth": "× per level",
        "splash": "design units",
        "falloff": "exponent",
        "projspeed": "design units/s",
        "money": "gold",
        "lives": "lives",
        "enemyspeed": "bracket position 0–1",
        "enemyhp": "bracket position 0–1",
        "enemybounty": "bracket position 0–1",
        "meleehp": "bracket position 0–1",
        "meleedamage": "bracket position 0–1",
    ]

    static func value(of perm: SweepPermutation, focus: SweepFocus, space: SweepSpace) -> (num: Double, label: String)? {
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

    static func emit(rows: [SweepRow], focus: SweepFocus, space: SweepSpace, sweepOut: String) throws {
        var byLabel: [String: FocusBucket] = [:]
        for row in rows {
            guard let (num, label) = value(of: row.perm, focus: focus, space: space) else { continue }
            var b = byLabel[label] ?? FocusBucket(value: num, label: label)
            b.wins.append(row.winRate)
            if row.winRate == 0 {
                b.unwinnable += 1
            } else if row.winRate == 1 && row.livesP10 >= Double(row.perm.lives) {
                b.trivial += 1
            } else if row.winRate < 0.6 {
                b.struggle += 1
            } else if row.winRate <= 0.95 {
                b.band += 1
            } else {
                b.comfortable += 1
            }
            b.naiveClearSum += row.w1NaiveClear
            b.greedyClearSum += row.w1GreedyClear
            b.histogram[min(9, Int(row.winRate * 10))] += 1
            byLabel[label] = b
        }
        var buckets = byLabel.values.sorted { $0.value < $1.value }
        for i in buckets.indices { buckets[i].wins.sort() }
        guard !buckets.isEmpty else {
            print("focus: no rows to aggregate")
            return
        }

        let best = buckets.max {
            ($0.bandShare, -abs($0.winPercentile(50) - 0.775)) < ($1.bandShare, -abs($1.winPercentile(50) - 0.775))
        }!

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

        var csv = "focus_value,label,perms,win_mean,win_p10,win_p25,win_p50,win_p75,win_p90,"
            + "unwinnable_share,struggle_share,band_share,comfortable_share,trivial_share,"
            + "naive_w1_clear,greedy_w1_clear\n"
        for b in buckets {
            let d = Double(max(1, b.n))
            csv += "\(b.value),\(b.label),\(b.n),"
                + String(format: "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,",
                         b.winMean, b.winPercentile(10), b.winPercentile(25),
                         b.winPercentile(50), b.winPercentile(75), b.winPercentile(90))
                + String(format: "%.4f,%.4f,%.4f,%.4f,%.4f,",
                         Double(b.unwinnable) / d, Double(b.struggle) / d, Double(b.band) / d,
                         Double(b.comfortable) / d, Double(b.trivial) / d)
                + String(format: "%.4f,%.4f\n", b.naiveClear, b.greedyClear)
        }
        try csv.write(toFile: csvPath, atomically: true, encoding: .utf8)

        let html = try renderHTML(buckets: buckets, focus: focus, space: space,
                                  best: best, rows: rows, csvPath: csvPath)
        try html.write(toFile: htmlPath, atomically: true, encoding: .utf8)

        let pretty = prettyNames[focus.stat] ?? focus.stat
        let kindNote = focus.kind.isEmpty ? "" : " (\(focus.kind))"
        func pct(_ v: Double) -> String { String(format: "%3.0f%%", v * 100) }
        func bar(_ v: Double, width: Int = 12) -> String {
            let filled = max(0, min(width, Int((v * Double(width)).rounded())))
            return String(repeating: "█", count: filled) + String(repeating: "·", count: width - filled)
        }
        print("\n── focus: \(pretty)\(kindNote) — \(space.fixedInputs.levelName) ──────────")
        print("  value      perms   win p50   in 60–95% band     sloppy W1")
        for b in buckets {
            let marker = b.label == best.label ? "  ← best band share" : ""
            print("  \(b.label.padding(toLength: 9, withPad: " ", startingAt: 0))"
                + "\(String(b.n).padding(toLength: 8, withPad: " ", startingAt: 0))"
                + "\(pct(b.winPercentile(50)))      \(bar(b.bandShare)) \(pct(b.bandShare))"
                + "      \(pct(b.naiveClear))\(marker)")
        }
        print("""
          aggregates: \(csvPath)
          charts:     \(htmlPath)  (open in a browser)
        ──────────────────────────────────────────────────────
        """)
    }

    static func renderHTML(buckets: [FocusBucket], focus: SweepFocus, space: SweepSpace,
                           best: FocusBucket, rows: [SweepRow], csvPath: String) throws -> String {
        func r4(_ v: Double) -> Double { (v * 10000).rounded() / 10000 }
        var values: [[String: Any]] = []
        for b in buckets {
            let d = Double(max(1, b.n))
            values.append([
                "value": b.value,
                "label": b.label,
                "n": b.n,
                "mean": r4(b.winMean),
                "p10": r4(b.winPercentile(10)),
                "p25": r4(b.winPercentile(25)),
                "p50": r4(b.winPercentile(50)),
                "p75": r4(b.winPercentile(75)),
                "p90": r4(b.winPercentile(90)),
                "unwinnable": r4(Double(b.unwinnable) / d),
                "struggle": r4(Double(b.struggle) / d),
                "band": r4(Double(b.band) / d),
                "comfortable": r4(Double(b.comfortable) / d),
                "trivial": r4(Double(b.trivial) / d),
                "naive": r4(b.naiveClear),
                "greedy": r4(b.greedyClear),
                "hist": b.histogram.map { r4(Double($0) / d) },
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
            "best": best.label,
            "seedsPerPerm": space.grids.seedsPerPermutation,
            "totalRows": rows.count,
            "values": values,
        ]
        let json = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let jsonString = String(data: json, encoding: .utf8) ?? "{}"

        let sub = "\(buckets.count) focus values × \(buckets.map(\.n).min() ?? 0) paired permutation samples "
            + "of every other variable · \(rows.count) sweep rows · ≤\(space.grids.seedsPerPermutation) seeds each"
        return htmlTemplate
            .replacingOccurrences(of: "__TITLE__", with: "\(pretty)\(kindNote) — \(space.fixedInputs.levelName)")
            .replacingOccurrences(of: "__SUB__", with: sub)
            .replacingOccurrences(of: "__FOOT__", with: "Generated \(df.string(from: Date())) · aggregates: \(csvPath)")
            .replacingOccurrences(of: "__PAYLOAD__", with: jsonString)
    }

    static let htmlTemplate = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
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
    --page: #f9f9f7; --surface: #fcfcfb; --ink: #0b0b0b; --ink2: #52514e;
    --muted: #898781; --grid: #e1e0d9; --axis: #c3c2b7;
    --border: rgba(11,11,11,0.10);
    --s1: #2a78d6; --s2: #eb6834;
  }
  @media (prefers-color-scheme: dark) {
    :root:where(:not([data-theme="light"])) .viz-root {
      --page: #0d0d0d; --surface: #1a1a19; --ink: #ffffff; --ink2: #c3c2b7;
      --muted: #898781; --grid: #2c2c2a; --axis: #383835;
      --border: rgba(255,255,255,0.10);
      --s1: #3987e5; --s2: #d95926;
    }
  }
  :root[data-theme="dark"] .viz-root {
    --page: #0d0d0d; --surface: #1a1a19; --ink: #ffffff; --ink2: #c3c2b7;
    --muted: #898781; --grid: #2c2c2a; --axis: #383835;
    --border: rgba(255,255,255,0.10);
    --s1: #3987e5; --s2: #d95926;
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
  .chart { position: relative; }
  .legend { display: flex; flex-wrap: wrap; gap: 14px; font-size: 12px; color: var(--ink2); margin: 6px 0 4px; }
  .legend .item { display: inline-flex; align-items: center; gap: 6px; }
  .legend .swatch { width: 11px; height: 11px; border-radius: 3px; display: inline-block; }
  .legend .linekey { width: 16px; height: 2px; border-radius: 1px; display: inline-block; }
  .tooltip {
    position: fixed; z-index: 10; pointer-events: none;
    background: var(--surface); color: var(--ink);
    border: 1px solid var(--border); border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.14);
    padding: 9px 12px; font-size: 12px; max-width: 260px;
  }
  .tooltip .tt-title { font-weight: 600; margin-bottom: 5px; }
  .tooltip .tt-row { display: flex; align-items: baseline; gap: 8px; margin-top: 2px; }
  .tooltip .tt-key { width: 12px; height: 2px; border-radius: 1px; flex: none; align-self: center; }
  .tooltip .tt-key.box { height: 9px; width: 9px; border-radius: 2px; }
  .tooltip .tt-val { font-weight: 600; font-variant-numeric: tabular-nums; }
  .tooltip .tt-name { color: var(--ink2); }
  .tablewrap { overflow-x: auto; }
  table { border-collapse: collapse; font-size: 12px; width: 100%; }
  th, td { text-align: right; padding: 6px 10px; font-variant-numeric: tabular-nums; white-space: nowrap; }
  th:first-child, td:first-child { text-align: left; }
  th { color: var(--ink2); font-weight: 600; border-bottom: 1px solid var(--axis); }
  td { border-bottom: 1px solid var(--grid); color: var(--ink); }
  tr.best td { font-weight: 650; }
  footer { color: var(--muted); font-size: 11px; margin-top: 20px; }
  svg text { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; }
  .hit:focus { outline: none; }
  .hit:focus-visible { stroke: var(--s1); stroke-width: 1.5; }
  .scalebar { display: flex; align-items: center; gap: 8px; font-size: 11px; color: var(--muted); margin: 4px 0 6px 44px; }
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
    <h2>Win rate across the focus grid</h2>
    <p class="chart-sub">Median win rate of the reference player; the dark band spans p25–p75 and the pale band p10–p90 across all sampled permutations of the other variables. Hairlines mark the 60–95% target band.</p>
    <div class="chart" id="winCurve"></div>
  </section>
  <section class="card">
    <h2>Difficulty composition</h2>
    <p class="chart-sub">How the permutations behind each focus value split by outcome, centered on the target band — the best value is the one holding the most weight near the center line.</p>
    <div class="legend" id="stackLegend"></div>
    <div class="chart" id="stack"></div>
  </section>
  <section class="card">
    <h2>Wave-1 economics</h2>
    <p class="chart-sub">Share of runs clearing wave 1 without a leak: optimal placement (greedy commander) vs sloppy placement (random slots). A gap that never closes means placement is doing all the work.</p>
    <div class="legend" id="w1Legend"></div>
    <div class="chart" id="w1"></div>
  </section>
  <section class="card">
    <h2>Win-rate distribution</h2>
    <p class="chart-sub">Full distribution behind the medians — each column is one focus value, binned by win rate; darker means more permutations landed in that bin. Split blobs reveal cliffs the median hides.</p>
    <div class="chart" id="heat"></div>
    <div class="scalebar" id="heatScale"></div>
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
    axis: "#383835", surface: "#1a1a19", s1: "#3987e5", s2: "#d95926",
    stack: { unwinnable: "#ee6a61", struggle: "#742f2a", band: "#787771",
             comfortable: "#2c5a96", trivial: "#9cc3f2" },
    ramp: ["#184f95", "#256abf", "#3987e5", "#5598e7", "#6da7ec", "#86b6ef", "#9ec5f4", "#b7d3f6", "#cde2fb"]
  } : {
    ink: "#0b0b0b", ink2: "#52514e", muted: "#898781", grid: "#e1e0d9",
    axis: "#c3c2b7", surface: "#fcfcfb", s1: "#2a78d6", s2: "#eb6834",
    stack: { unwinnable: "#8f1d1a", struggle: "#f6b3af", band: "#92918a",
             comfortable: "#aecdf6", trivial: "#16457f" },
    ramp: ["#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5", "#256abf", "#1c5cab", "#104281"]
  };
}

const STACK_ORDER = ["unwinnable", "struggle", "band", "comfortable", "trivial"];
const STACK_NAMES = {
  unwinnable: "Unwinnable (0% win)", struggle: "Struggle (<60%)",
  band: "Target band (60–95%)", comfortable: "Comfortable (>95%)",
  trivial: "Trivial (100%, no lives lost)"
};

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
      k.className = "tt-key" + (r.box ? " box" : "");
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

function geometry(container, height) {
  const w = Math.max(420, container.clientWidth);
  return { w, h: height, ml: 44, mr: 14, mt: 12, mb: 26 };
}
function slotX(g, i, n) { return g.ml + (i + 0.5) * ((g.w - g.ml - g.mr) / n); }
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

function renderWinCurve() {
  const box = document.getElementById("winCurve");
  box.replaceChildren();
  const C = colors();
  const g = geometry(box, 300);
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  const y = v => g.mt + (1 - v) * (g.h - g.mt - g.mb);
  yAxisPct(svg, g, C, [0, 0.25, 0.5, 0.75, 1]);
  for (const lvl of [0.6, 0.95]) {
    el("line", { x1: g.ml, x2: g.w - g.mr, y1: y(lvl), y2: y(lvl), stroke: C.axis, "stroke-width": 1 }, svg);
    textEl(svg, g.w - g.mr - 2, y(lvl) - 4, "target " + pct(lvl), C.muted, 10, "end");
  }
  const px = i => slotX(g, i, n);
  const outer = DATA.values.map((d, i) => [px(i), y(d.p90)])
    .concat(DATA.values.map((d, i) => [px(n - 1 - i), y(DATA.values[n - 1 - i].p10)]));
  el("path", { d: linePath(outer) + " Z", fill: C.s1, opacity: 0.10 }, svg);
  const inner = DATA.values.map((d, i) => [px(i), y(d.p75)])
    .concat(DATA.values.map((d, i) => [px(n - 1 - i), y(DATA.values[n - 1 - i].p25)]));
  el("path", { d: linePath(inner) + " Z", fill: C.s1, opacity: 0.18 }, svg);
  el("path", { d: linePath(DATA.values.map((d, i) => [px(i), y(d.p50)])),
               fill: "none", stroke: C.s1, "stroke-width": 2,
               "stroke-linecap": "round", "stroke-linejoin": "round" }, svg);
  DATA.values.forEach((d, i) => {
    el("circle", { cx: px(i), cy: y(d.p50), r: 4, fill: C.s1, stroke: C.surface, "stroke-width": 2 }, svg);
    if (d.label === DATA.best) {
      const ly = y(d.p50) - 12;
      textEl(svg, px(i), ly < g.mt + 10 ? y(d.p50) + 22 : ly, pct(d.p50), C.ink2, 11, "middle", 600);
    }
  });
  xTicks(svg, g, C);
  const cross = el("line", { y1: g.mt, y2: g.h - g.mb, stroke: C.axis, "stroke-width": 1, visibility: "hidden" }, svg);
  const hit = el("rect", { x: g.ml, y: 0, width: g.w - g.ml - g.mr, height: g.h, fill: "transparent" }, svg);
  hit.addEventListener("pointermove", evt => {
    const rect = svg.getBoundingClientRect();
    const mx = evt.clientX - rect.left;
    let i = Math.round((mx - g.ml) / slotW(g, n) - 0.5);
    i = Math.max(0, Math.min(n - 1, i));
    const d = DATA.values[i];
    cross.setAttribute("x1", px(i)); cross.setAttribute("x2", px(i));
    cross.setAttribute("visibility", "visible");
    showTooltip(evt, DATA.focusPretty + " " + d.label, [
      { name: "median win", value: pct(d.p50, 1), key: C.s1 },
      { name: "mean win", value: pct(d.mean, 1) },
      { name: "p25 – p75", value: pct(d.p25) + " – " + pct(d.p75) },
      { name: "p10 – p90", value: pct(d.p10) + " – " + pct(d.p90) },
      { name: "permutations", value: String(d.n) }
    ]);
  });
  hit.addEventListener("pointerleave", () => { cross.setAttribute("visibility", "hidden"); hideTooltip(); });
}

function renderStack() {
  const box = document.getElementById("stack");
  box.replaceChildren();
  const C = colors();
  const legend = document.getElementById("stackLegend");
  legend.replaceChildren();
  for (const key of STACK_ORDER) {
    const item = document.createElement("span");
    item.className = "item";
    const sw = document.createElement("span");
    sw.className = "swatch";
    sw.style.background = C.stack[key];
    item.appendChild(sw);
    item.appendChild(document.createTextNode(STACK_NAMES[key]));
    legend.appendChild(item);
  }
  const g = geometry(box, 300);
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  let extent = 0;
  for (const d of DATA.values) {
    extent = Math.max(extent, d.unwinnable + d.struggle + d.band / 2,
                      d.comfortable + d.trivial + d.band / 2);
  }
  extent = Math.max(extent, 0.05);
  const mid = g.mt + (g.h - g.mt - g.mb) / 2;
  const scale = (g.h - g.mt - g.mb) / 2 / extent;
  const bw = Math.min(24, slotW(g, n) - 8);
  textEl(svg, g.ml + 4, g.mt + 9, "too easy", C.muted, 10);
  textEl(svg, g.ml + 4, g.h - g.mb - 5, "too hard", C.muted, 10);
  DATA.values.forEach((d, i) => {
    const x = slotX(g, i, n) - bw / 2;
    let yTop = mid + (d.unwinnable + d.struggle + d.band / 2) * scale;
    for (const key of STACK_ORDER) {
      const hpx = d[key] * scale;
      if (hpx > 0.5) {
        el("rect", { x, y: yTop - hpx + 1, width: bw, height: Math.max(1, hpx - 2),
                     rx: 1.5, fill: C.stack[key] }, svg);
      }
      yTop -= hpx;
    }
    const hit = el("rect", { x: slotX(g, i, n) - slotW(g, n) / 2, y: g.mt,
                             width: slotW(g, n), height: g.h - g.mt - g.mb,
                             fill: "transparent", tabindex: 0, class: "hit" }, svg);
    const show = evt => showTooltip(evt.clientX !== undefined ? evt : { clientX: g.w / 2, clientY: 200 },
      DATA.focusPretty + " " + d.label, STACK_ORDER.slice().reverse().map(key => (
        { name: STACK_NAMES[key], value: pct(d[key]), key: C.stack[key], box: true }
      )).concat([{ name: "permutations", value: String(d.n) }]));
    hit.addEventListener("pointermove", show);
    hit.addEventListener("pointerleave", hideTooltip);
    hit.addEventListener("focus", show);
    hit.addEventListener("blur", hideTooltip);
  });
  el("line", { x1: g.ml, x2: g.w - g.mr, y1: mid, y2: mid, stroke: C.axis, "stroke-width": 1 }, svg);
  xTicks(svg, g, C);
}

function renderW1() {
  const box = document.getElementById("w1");
  box.replaceChildren();
  const C = colors();
  const legend = document.getElementById("w1Legend");
  legend.replaceChildren();
  const series = [
    { key: "greedy", name: "Optimal opening", color: C.s1 },
    { key: "naive", name: "Sloppy opening", color: C.s2 }
  ];
  for (const s of series) {
    const item = document.createElement("span");
    item.className = "item";
    const sw = document.createElement("span");
    sw.className = "linekey";
    sw.style.background = s.color;
    item.appendChild(sw);
    item.appendChild(document.createTextNode(s.name));
    legend.appendChild(item);
  }
  const g = geometry(box, 240);
  g.mr = 76;
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  const y = v => g.mt + (1 - v) * (g.h - g.mt - g.mb);
  yAxisPct(svg, g, C, [0, 0.5, 1]);
  for (const s of series) {
    el("path", { d: linePath(DATA.values.map((d, i) => [slotX(g, i, n), y(d[s.key])])),
                 fill: "none", stroke: s.color, "stroke-width": 2,
                 "stroke-linecap": "round", "stroke-linejoin": "round" }, svg);
    const last = DATA.values[n - 1];
    el("circle", { cx: slotX(g, n - 1, n), cy: y(last[s.key]), r: 4,
                   fill: s.color, stroke: C.surface, "stroke-width": 2 }, svg);
    textEl(svg, slotX(g, n - 1, n) + 10, y(last[s.key]) + 4,
           s.key === "greedy" ? "optimal" : "sloppy", C.ink2, 11);
  }
  xTicks(svg, g, C);
  const cross = el("line", { y1: g.mt, y2: g.h - g.mb, stroke: C.axis, "stroke-width": 1, visibility: "hidden" }, svg);
  const hit = el("rect", { x: g.ml, y: 0, width: g.w - g.ml - g.mr, height: g.h, fill: "transparent" }, svg);
  hit.addEventListener("pointermove", evt => {
    const rect = svg.getBoundingClientRect();
    let i = Math.round((evt.clientX - rect.left - g.ml) / slotW(g, n) - 0.5);
    i = Math.max(0, Math.min(n - 1, i));
    const d = DATA.values[i];
    cross.setAttribute("x1", slotX(g, i, n)); cross.setAttribute("x2", slotX(g, i, n));
    cross.setAttribute("visibility", "visible");
    showTooltip(evt, DATA.focusPretty + " " + d.label, [
      { name: "optimal W1 clear", value: pct(d.greedy, 1), key: C.s1 },
      { name: "sloppy W1 clear", value: pct(d.naive, 1), key: C.s2 }
    ]);
  });
  hit.addEventListener("pointerleave", () => { cross.setAttribute("visibility", "hidden"); hideTooltip(); });
}

function lerpHex(a, b, t) {
  const pa = [1, 3, 5].map(i => parseInt(a.slice(i, i + 2), 16));
  const pb = [1, 3, 5].map(i => parseInt(b.slice(i, i + 2), 16));
  return "#" + pa.map((v, i) => Math.round(v + (pb[i] - v) * t).toString(16).padStart(2, "0")).join("");
}
function rampColor(C, t) {
  const r = C.ramp;
  const x = Math.max(0, Math.min(1, t)) * (r.length - 1);
  const i = Math.min(r.length - 2, Math.floor(x));
  return lerpHex(r[i], r[i + 1], x - i);
}

function renderHeat() {
  const box = document.getElementById("heat");
  box.replaceChildren();
  const C = colors();
  const bins = 10;
  const g = geometry(box, 280);
  const svg = el("svg", { width: g.w, height: g.h, viewBox: `0 0 ${g.w} ${g.h}` }, null);
  box.appendChild(svg);
  const n = DATA.values.length;
  const plotH = g.h - g.mt - g.mb;
  const cellH = plotH / bins;
  const cw = Math.min(40, slotW(g, n) - 4);
  let maxShare = 0.0001;
  for (const d of DATA.values) for (const s of d.hist) maxShare = Math.max(maxShare, s);
  for (const frac of [0, 0.5, 1]) {
    textEl(svg, g.ml - 6, g.mt + (1 - frac) * plotH + 4, pct(frac), C.muted, 10, "end");
  }
  DATA.values.forEach((d, i) => {
    for (let b = 0; b < bins; b++) {
      const share = d.hist[b];
      const cy = g.mt + (bins - 1 - b) * cellH;
      const rect = el("rect", {
        x: slotX(g, i, n) - cw / 2, y: cy + 1, width: cw, height: cellH - 2, rx: 2,
        fill: share > 0 ? rampColor(C, share / maxShare) : "transparent",
        stroke: share > 0 ? "none" : C.grid, "stroke-width": share > 0 ? 0 : 0.5,
        tabindex: 0, class: "hit"
      }, svg);
      const show = evt => showTooltip(evt.clientX !== undefined ? evt : { clientX: g.w / 2, clientY: 300 },
        DATA.focusPretty + " " + d.label, [
          { name: "win rate " + (b * 10) + "–" + (b + 1) * 10 + "%", value: pct(share, 1) + " of permutations" },
          { name: "count", value: Math.round(share * d.n) + " of " + d.n }
        ]);
      rect.addEventListener("pointermove", show);
      rect.addEventListener("pointerleave", hideTooltip);
      rect.addEventListener("focus", show);
      rect.addEventListener("blur", hideTooltip);
    }
  });
  el("line", { x1: g.ml, x2: g.w - g.mr, y1: g.h - g.mb, y2: g.h - g.mb, stroke: C.axis, "stroke-width": 1 }, svg);
  xTicks(svg, g, C);
  const scale = document.getElementById("heatScale");
  scale.replaceChildren();
  scale.appendChild(document.createTextNode("0%"));
  const bar = document.createElement("span");
  bar.style.cssText = "display:inline-block;width:120px;height:10px;border-radius:5px;"
    + "background:linear-gradient(to right," + C.ramp.join(",") + ")";
  scale.appendChild(bar);
  scale.appendChild(document.createTextNode(pct(maxShare) + " of a value's permutations"));
}

function renderKpis() {
  const box = document.getElementById("kpis");
  box.replaceChildren();
  const best = DATA.values.find(d => d.label === DATA.best);
  if (!best) return;
  function tile(label, value, note, hero) {
    const t = document.createElement("div");
    t.className = "tile" + (hero ? " hero" : "");
    const l = document.createElement("div"); l.className = "label"; l.textContent = label;
    const v = document.createElement("div"); v.className = "value"; v.textContent = value;
    t.appendChild(l); t.appendChild(v);
    if (note) { const nt = document.createElement("div"); nt.className = "note"; nt.textContent = note; t.appendChild(nt); }
    box.appendChild(t);
  }
  tile("Best value — " + DATA.focusPretty, best.label,
       (DATA.unit ? DATA.unit + " · " : "") + "largest target-band share", true);
  tile("Target-band share at best", pct(best.band), "permutations landing at 60–95% win");
  tile("Median win at best", pct(best.p50, 1), "across " + best.n + " permutations");
  tile("Sloppy wave-1 clear at best", pct(best.naive), "random-slot opening survives wave 1");
}

function renderTable() {
  const box = document.getElementById("table");
  box.replaceChildren();
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const hr = document.createElement("tr");
  for (const h of ["Value", "Perms", "Win mean", "p10", "p50", "p90", "Unwinnable",
                   "Struggle", "Target band", "Comfortable", "Trivial", "Sloppy W1", "Optimal W1"]) {
    const th = document.createElement("th");
    th.textContent = h;
    hr.appendChild(th);
  }
  thead.appendChild(hr);
  table.appendChild(thead);
  const tbody = document.createElement("tbody");
  for (const d of DATA.values) {
    const tr = document.createElement("tr");
    if (d.label === DATA.best) tr.className = "best";
    for (const v of [d.label, d.n, pct(d.mean, 1), pct(d.p10, 1), pct(d.p50, 1), pct(d.p90, 1),
                     pct(d.unwinnable, 1), pct(d.struggle, 1), pct(d.band, 1),
                     pct(d.comfortable, 1), pct(d.trivial, 1), pct(d.naive, 1), pct(d.greedy, 1)]) {
      const td = document.createElement("td");
      td.textContent = String(v);
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }
  table.appendChild(tbody);
  box.appendChild(table);
}

function renderAll() {
  renderKpis();
  renderWinCurve();
  renderStack();
  renderW1();
  renderHeat();
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
