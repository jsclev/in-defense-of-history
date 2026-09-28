import { z } from 'zod';
import type { Point } from '../hud/layout';

const xy = z.tuple([z.number().finite(), z.number().finite()]);
export const navigationSchema = z.record(z.string(), z.array(z.array(xy).min(4).refine(ring =>
  ring[0]![0] === ring.at(-1)![0] && ring[0]![1] === ring.at(-1)![1], 'Unclosed road boundary')).nonempty());
export const distance = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);
export const equal = (a: Point, b: Point) => a.x === b.x && a.y === b.y;
export const lerp = (a: Point, b: Point, t: number): Point => ({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t });
export function closest(p: Point, a: Point, b: Point): Point {
  const dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy;
  return lerp(a, b, length === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length)));
}
export const swiftRound = (n: number) => Math.sign(n) * Math.floor(Math.abs(n) + .5);
type Edge = [Point, Point];
function insideEdges(p: Point, edges: Edge[]) {
  let inside = false;
  for (const [a, b] of edges) {
    if (distance(p, closest(p, a, b)) <= 1e-7) return true;
    if ((a.y > p.y) !== (b.y > p.y) && p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)) inside = !inside;
  }
  return inside;
}

class Heap<T> {
  private entries: { value: T; priority: number }[] = [];
  push(value: T, priority: number) {
    const a = this.entries; a.push({ value, priority }); let i = a.length - 1;
    while (i > 0) { const parent = Math.floor((i - 1) / 2); if (a[i]!.priority >= a[parent]!.priority) break;
      [a[i], a[parent]] = [a[parent]!, a[i]!]; i = parent; }
  }
  pop(): T | undefined {
    const a = this.entries; if (!a.length) return undefined;
    [a[0], a[a.length - 1]] = [a.at(-1)!, a[0]!]; const result = a.pop()!.value; let i = 0;
    while (2 * i + 1 < a.length) { let child = 2 * i + 1;
      if (child + 1 < a.length && a[child + 1]!.priority < a[child]!.priority) child++;
      if (a[child]!.priority >= a[i]!.priority) break;
      [a[i], a[child]] = [a[child]!, a[i]!]; i = child; }
    return result;
  }
}
// Path.swift: distances and placement use the same canonical coordinate system.
export class Route {
  readonly lengths = [0]; readonly total: number;
  constructor(readonly points: Point[]) {
    if (points.length < 2 || points.some(p => !Number.isFinite(p.x + p.y))) throw Error('Invalid enemy route points');
    for (let i = 1; i < points.length; i++) this.lengths.push(this.lengths[i - 1]! + distance(points[i - 1]!, points[i]!));
    this.total = this.lengths.at(-1)!;
    if (this.total <= 0) throw Error('Enemy route requires distinct points');
  }
  point(at: number): Point {
    if (at <= 0) return this.points[0]!;
    if (at >= this.total) return this.points.at(-1)!;
    const i = this.lengths.findIndex(length => length > at);
    return lerp(this.points[i - 1]!, this.points[i]!, (at - this.lengths[i - 1]!) / (this.lengths[i]! - this.lengths[i - 1]!));
  }
  nearest(p: Point): { point: Point; along: number; gap: number } {
    let best = { point: this.points[0]!, along: 0, gap: Infinity };
    for (let i = 1; i < this.points.length; i++) {
      const a = this.points[i - 1]!, point = closest(p, a, this.points[i]!), gap = distance(point, p);
      if (gap < best.gap) best = { point, gap, along: this.lengths[i - 1]! + distance(a, point) };
    }
    return best;
  }
}
// HeroMovementArea.swift: consume the exact native flattened/unioned boundaries,
// then run its grid A*, verified shortcuts and narrow-passage visibility search.
export class MovementArea {
  private readonly edges: [Point, Point][] = [];
  private readonly rows = new Map<number, [Point, Point][]>();
  private readonly neighbors = new Map<string, Point[]>();
  private readonly walkable = new Map<string, boolean>();
  private readonly vertices: Point[];
  private readonly components: Edge[][];
  constructor(readonly rings: number[][][]) {
    const boundaries: Edge[][] = [];
    for (const ring of rings) boundaries.push(ring.slice(1).map((p, i) => [{ x: ring[i]![0]!, y: ring[i]![1]! }, { x: p[0]!, y: p[1]! }]));
    for (const [a, b] of boundaries.flat()) {
      if (equal(a, b)) continue;
      this.edges.push([a, b]);
      for (let row = Math.floor(Math.min(a.y, b.y) / 32); row <= Math.floor(Math.max(a.y, b.y) / 32); row++) {
        if (!this.rows.has(row)) this.rows.set(row, []); this.rows.get(row)!.push([a, b]);
      }
    }
    this.vertices = [...new Map(this.edges.map(([a]) => [key(a), a])).values()].sort((a, b) => a.x - b.x || a.y - b.y);
    const boxArea = (edges: Edge[]) => {
      const xs = edges.map(([p]) => p.x), ys = edges.map(([p]) => p.y);
      return (Math.max(...xs) - Math.min(...xs)) * (Math.max(...ys) - Math.min(...ys));
    };
    this.components = boundaries.filter((ring, i) => boundaries.filter((other, j) => i !== j && insideEdges(ring[0]![0], other)).length % 2 === 0)
      .sort((a, b) => boxArea(a) - boxArea(b));
  }
  contains(p: Point): boolean {
    if (!Number.isFinite(p.x + p.y)) return false;
    return insideEdges(p, this.rows.get(Math.floor(p.y / 32)) ?? []);
  }
  segment(start: Point, end: Point): boolean {
    if (!this.contains(start) || !this.contains(end)) return false;
    if (equal(start, end)) return true;
    const dx = end.x - start.x, dy = end.y - start.y, cuts = [0, 1];
    const candidates = new Set<[Point, Point]>();
    for (let row = Math.floor(Math.min(start.y, end.y) / 32); row <= Math.floor(Math.max(start.y, end.y) / 32); row++)
      for (const edge of this.rows.get(row) ?? []) candidates.add(edge);
    for (const [a, b] of candidates) {
      if (Math.max(a.x, b.x) < Math.min(start.x, end.x) || Math.min(a.x, b.x) > Math.max(start.x, end.x)) continue;
      const ex = b.x - a.x, ey = b.y - a.y, denominator = dx * ey - dy * ex;
      if (Math.abs(denominator) > 1e-12) {
        const t = ((a.x - start.x) * ey - (a.y - start.y) * ex) / denominator;
        const u = ((a.x - start.x) * dy - (a.y - start.y) * dx) / denominator;
        if (t > 0 && t < 1 && u >= 0 && u <= 1) cuts.push(t);
      } else for (const p of [a, b]) if (distance(p, closest(p, start, end)) <= 1e-7)
        cuts.push(((p.x - start.x) * dx + (p.y - start.y) * dy) / (dx * dx + dy * dy));
    }
    cuts.sort((a, b) => a - b);
    return cuts.slice(1).every((b, i) => b - cuts[i]! <= 1e-12 || this.contains(lerp(start, end, (cuts[i]! + b) / 2)));
  }
  nearest(p: Point): Point | null {
    if (!Number.isFinite(p.x + p.y)) return null;
    if (this.contains(p)) return p;
    return this.edges.map(([a, b]) => closest(p, a, b)).reduce<Point | null>((best, point) =>
      best === null || distance(point, p) < distance(best, p) ? point : best, null);
  }
  private links(p: Point, radius: number): Point[] {
    const result: Point[] = [], x = swiftRound(p.x / 16), y = swiftRound(p.y / 16);
    for (let dx = -radius; dx <= radius; dx++) for (let dy = -radius; dy <= radius; dy++) {
      if (radius === 1 && dx === 0 && dy === 0) continue;
      const next = { x: (x + dx) * 16, y: (y + dy) * 16 }, id = key(next);
      if (!this.walkable.has(id)) this.walkable.set(id, this.contains(next));
      if (this.walkable.get(id) && this.segment(p, next)) result.push(next);
    }
    return result;
  }
  route(start: Point, end: Point): Point[] | null {
    if (!this.contains(start) || !this.contains(end)) return null;
    if (this.components.findIndex(ring => insideEdges(start, ring)) !== this.components.findIndex(ring => insideEdges(end, ring))) return null;
    if (equal(start, end)) return [];
    if (this.segment(start, end)) return [end];
    const goals = new Set(this.links(end, 2).map(key));
    const grid = this.search(this.links(start, 2), start, end, p => goals.has(key(p)), p => {
      if (!this.neighbors.has(key(p))) this.neighbors.set(key(p), this.links(p, 1));
      return this.neighbors.get(key(p))!;
    });
    if (grid) {
      const result: Point[] = []; let current = start, index = 0;
      while (index < grid.length) {
        let next = grid.length - 1;
        if (next > index && !this.segment(current, grid[next]!)) {
          let visible = index, blocked = next;
          while (visible + 1 < blocked) { const candidate = Math.floor((visible + blocked) / 2);
            if (this.segment(current, grid[candidate]!)) visible = candidate; else blocked = candidate; }
          next = visible;
        }
        result.push(grid[next]!); current = grid[next]!; index = next + 1;
      }
      return result;
    }
    return this.search([start], start, end, p => equal(p, end), p => [end, ...this.vertices].filter(n => this.segment(p, n)));
  }
  private search(starts: Point[], start: Point, end: Point, goal: (p: Point) => boolean, links: (p: Point) => Point[]): Point[] | null {
    const open = new Heap<Point>(), distances = new Map<string, number>(), previous = new Map<string, Point>(), settled = new Set<string>();
    for (const p of starts) { const d = distance(start, p); distances.set(key(p), d); open.push(p, d + distance(p, end)); }
    for (let p = open.pop(); p; p = open.pop()) {
      const id = key(p); if (settled.has(id)) continue; settled.add(id);
      if (goal(p)) { const route = equal(p, end) ? [] : [end]; let at: Point | undefined = p;
        while (at && !equal(at, start)) { route.push(at); at = previous.get(key(at)); } return route.reverse(); }
      for (const next of links(p)) {
        const nextID = key(next), d = distances.get(id)! + distance(p, next);
        if (!settled.has(nextID) && d < (distances.get(nextID) ?? Infinity)) {
          distances.set(nextID, d); previous.set(nextID, p); open.push(next, d + distance(next, end));
        }
      }
    }
    return null;
  }
}
function key(p: Point) { return `${p.x},${p.y}`; }
