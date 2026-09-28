import { bottom, contains, right, type Point, type Rect } from './layout';

export type Region = { bounds: Rect; cuts: Rect[] };
export const inRegion = (region: Region, point: Point) => contains(region.bounds, point) && !region.cuts.some(cut => contains(cut, point));

// Exact boundary of an axis-aligned rectangle minus rectangles. Join boundary
// edges into loops so SVG dashes continue around each cutout, like CGPath.
export function regionPath(region: Region): string {
  const { bounds, cuts } = region;
  if (bounds.width <= 0 || bounds.height <= 0) return '';
  const axis = (start: number, end: number, values: number[]) => [...new Set([start, end, ...values.filter(v => v > start && v < end)])].sort((a, b) => a - b);
  const xs = axis(bounds.x, right(bounds), cuts.flatMap(r => [r.x, right(r)]));
  const ys = axis(bounds.y, bottom(bounds), cuts.flatMap(r => [r.y, bottom(r)]));
  const cells = ys.slice(1).map((y, j) => xs.slice(1).map((x, i) => inRegion(region, { x: (xs[i]! + x) / 2, y: (ys[j]! + y) / 2 })));
  const edges = new Map<string, string[]>();
  const add = (x1: number, y1: number, x2: number, y2: number) => {
    const key = `${x1},${y1}`, to = `${x2},${y2}`;
    edges.set(key, [...edges.get(key) ?? [], to]);
  };
  cells.forEach((row, j) => row.forEach((filled, i) => {
    if (!filled) return;
    const x = xs[i]!, xx = xs[i + 1]!, y = ys[j]!, yy = ys[j + 1]!;
    if (!cells[j - 1]?.[i]) add(x, y, xx, y);
    if (!row[i + 1]) add(xx, y, xx, yy);
    if (!cells[j + 1]?.[i]) add(xx, yy, x, yy);
    if (!row[i - 1]) add(x, yy, x, y);
  }));
  const loops: string[] = [];
  while (edges.size) {
    const start = edges.keys().next().value!;
    let cursor = start, path = `M${start}`;
    do {
      const next = edges.get(cursor)!;
      const to = next.pop()!;
      if (!next.length) edges.delete(cursor);
      path += `L${to}`; cursor = to;
    } while (cursor !== start);
    loops.push(`${path}Z`);
  }
  return loops.join('');
}
