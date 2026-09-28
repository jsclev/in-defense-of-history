import type { Row } from '../data/records';
import { projection, type Insets } from '../game/projection';
import type { Presentation } from '../content/presentation';

export type Rect = { x: number; y: number; width: number; height: number };
export type Point = { x: number; y: number };
export type Corner = Row<'player_hud_layout'>['hud_location_name'];
export type Section = Row<'player_hud_layout'>['hud_section_name'];
export type Canvas = Row<'virtual_canvas'>;
export const hudSizing = { referencePlayableHeight: 680.625, paintedButtonIconFraction: 0.64 };
export const corners: Corner[] = ['north_west', 'north_east', 'south_west', 'south_east'];
export const right = (r: Rect) => r.x + r.width;
export const bottom = (r: Rect) => r.y + r.height;
export const inset = (r: Rect, x: number, y: number): Rect => ({ x: r.x + x, y: r.y + y, width: r.width - 2 * x, height: r.height - 2 * y });
export const contains = (r: Rect, p: Point) => p.x >= r.x && p.x <= right(r) && p.y >= r.y && p.y <= bottom(r);

// The unavoidable geometry port of RuntimeCanvas, VirtualCanvas and HudPlayArea.
// SQL owns every canvas dimension and corner fraction. Projection is shared with
// the battlefield; neither CSS breakpoints nor the HUD can resize the map.
export function hudCanvas(canvas: Canvas, width: number, height: number, towerGeometry:Presentation['towerGeometry'], insets?: Insets) {
  const view = projection(canvas, width, height, insets);
  const { physicalRect: physical, safeRect: safe, playArea: play } = view;
  const horizontalMargin = play.width * 0.02, verticalMargin = play.height * 0.02;
  const left = Math.max(Math.min(safe.x, play.x), physical.x + horizontalMargin);
  const end = Math.max(right(safe), right(play)) - (right(physical) - right(safe) < horizontalMargin ? horizontalMargin : 0);
  const top = Math.min(safe.y, play.y) + verticalMargin;
  const base = physical.height - safe.height > verticalMargin ? bottom(safe) : bottom(play);
  const bounds = { x: left, y: top, width: end - left, height: base - top };
  const size = (section: 'stats_view' | 'master_controls' | 'hero_bar' | 'misc_view') => ({
    width: play.width * canvas[`${section}_width_fraction`],
    height: play.height * canvas[`${section}_height_fraction`] * 0.9,
  });
  const reservations = (bounds: Rect): Record<Corner, Rect> => ({
    north_west: anchor(size('stats_view'), bounds, 'north_west'),
    north_east: anchor(size('master_controls'), bounds, 'north_east'),
    south_west: anchor(size('hero_bar'), bounds, 'south_west'),
    south_east: anchor(size('misc_view'), bounds, 'south_east'),
  });
  const hud = reservations(bounds), road = reservations(play);
  road.south_west = { ...road.south_west, y: bottom(play) - road.south_west.height * 1.3, height: road.south_west.height * 1.3 };
  const bottomWidth = Math.min(play.width, physical.width * (315 / 1133));
  const home = { x: play.x + (play.width - bottomWidth) / 2, y: bottom(play) - hud.south_west.height * 0.2,
    width: bottomWidth, height: hud.south_west.height * 0.2 };
  const topExclusion = { x: right(road.north_west), y: play.y,
    width: Math.max(0, road.north_east.x - right(road.north_west)), height: play.height * 0.09 };
  const pathCuts = [...Object.values(road), home, topExclusion];
  const tapCuts = [...pathCuts, { ...topExclusion, height: play.height * 0.05 }, ...Object.values(hud)];
  // TowerMenuLayout.interactionExtent includes every square touch target/seat.
  const halfButton = play.height * towerGeometry.button / 2;
  const interaction = play.height * Math.max(towerGeometry.ring,towerGeometry.seat) + halfButton;
  const menuX = Math.max(canvas.tower_menu_total_width * view.scale / 2, interaction);
  const menuY = Math.max(canvas.tower_menu_total_height * view.scale / 2, interaction);
  const slotX = menuX - canvas.slot_width * view.scale / 2;
  const slotY = menuY - canvas.slot_height * view.scale / 2;
  const slot = { bounds: inset(play, slotX, slotY), cuts: [...Object.values(hud), home].map(r => inset(r, -slotX, -slotY)) };
  return { ...view, bounds, corners: hud, path: { bounds: play, cuts: pathCuts },
    tap: { bounds: play, cuts: tapCuts }, slot };
}
export type HudCanvas = ReturnType<typeof hudCanvas>;

// Outside-edge anchoring from HudPlayArea.fittedFrame / HudButtonRowLayout.
export function anchor(size: Pick<Rect, 'width' | 'height'>, corner: Rect, location: Corner): Rect {
  return { ...size, x: location.endsWith('east') ? right(corner) - size.width : corner.x,
    y: location.startsWith('south') ? bottom(corner) - size.height : corner.y };
}
export function buttonRow(view: HudCanvas, location: Corner, count: number) {
  if (!Number.isInteger(count) || count <= 0) throw new Error('HUD button count must be positive');
  const corner = view.corners[location];
  const sections = count + (count - 1) * 0.1;
  const side = Math.max(0, Math.min(corner.width / sections, corner.height));
  const gap = side * 0.1;
  const frame = anchor({ width: sections * side, height: side }, corner, location);
  return { frame, side, gap, buttons: Array.from({ length: count }, (_, i) => ({ x: frame.x + i * (side + gap), y: frame.y, width: side, height: side })) };
}
const dimension = (reference: number, scale: number, floor = 0.62) => Math.min(Math.max(reference * scale, reference * floor), reference * 1.2);
const counterWidth = (text: string, font: number, pad: number) => [...text].reduce((w, c) => w + (c === ',' ? 0.32 : 0.70) * font, pad);

// HudStatsView.dimensions uses StatsPanelLayout's counter dimensions, then fits
// the entire fixed template uniformly inside its assigned reservation.
export function statsLayout(view: HudCanvas, location: Corner, livesAspect: number, moneyAspect: number) {
  const scale = view.playArea.height / hudSizing.referencePlayableHeight;
  const pad = dimension(5, scale), gap = 2.5 * pad;
  const font = Math.min(Math.max(28.57 * scale, 28.57 * 0.682, 12.87), 28.57 * 1.2);
  const livesH = dimension(41.86, scale), moneyH = dimension(43.6, scale);
  const spacing = dimension(8, scale);
  const livesValue = dimension(60, scale), moneyValue = counterWidth('9,999', font, dimension(3, scale));
  const livesWidth = livesH * livesAspect + livesValue + spacing + 4 * pad;
  const moneyWidth = moneyH * moneyAspect + moneyValue + spacing + 4 * pad;
  const plateH = Math.max(livesH, moneyH) + 2 * pad;
  const waveWidth = counterWidth('99 of 99', font, 2 * pad);
  const rowWidth = livesWidth + moneyWidth + gap;
  const width = Math.max(rowWidth, waveWidth), height = 2 * plateH + gap;
  const corner = view.corners[location];
  const fit = Math.max(0, Math.min(corner.width / width, corner.height / height));
  const frame = anchor({ width: width * fit, height: height * fit }, corner, location);
  const rect = (x: number, y: number, w: number, h: number): Rect => ({ x: frame.x + x * fit, y: frame.y + y * fit, width: w * fit, height: h * fit });
  const rowX = (width - rowWidth) / 2;
  const counter = (x: number, w: number, iconH: number, aspect: number, valueWidth: number) => ({
    plate: rect(x, 0, w, plateH), icon: rect(x + 3 * pad, (plateH - iconH) / 2, iconH * aspect, iconH),
    value: rect(x + 3 * pad + iconH * aspect + spacing, 0, valueWidth, plateH),
  });
  return { frame, font: font * fit, radius: 1.5 * dimension(10, scale) * fit,
    lives: counter(rowX, livesWidth, livesH, livesAspect, livesValue),
    money: counter(rowX + livesWidth + gap, moneyWidth, moneyH, moneyAspect, moneyValue),
    wave: rect((width - waveWidth) / 2, plateH + gap, waveWidth, plateH) };
}
export function waveLayout(view: HudCanvas, position: Point) {
  const center = view.point(position.x, position.y);
  const side = Math.min(Math.max(70 * view.playArea.height / hudSizing.referencePlayableHeight, 44), 84);
  return { frame: { x: center.x - side / 2, y: center.y - side / 2, width: side, height: side },
    font: Math.max(side * 0.22, 12.87), horizontalPadding: side * 5 / 44, verticalPadding: side * 2 / 44 };
}

export function location(config: Row<'player_hud_layout'>[], section: Section): Corner {
  const rows = config.filter(row => row.hud_section_name === section);
  if (rows.length !== 1) throw new Error(`player_hud_layout.${section}: expected one location`);
  return rows[0]!.hud_location_name;
}
