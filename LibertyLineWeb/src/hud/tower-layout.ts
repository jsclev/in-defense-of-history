import type { Presentation } from '../content/presentation';
import { resolveHeight } from '../content/presentation';
import { requireImage, type Manifest } from '../content/schema';
import type { TowerTier, UpgradePath } from '../data/contracts';
import { towerKind } from '../data/records';
import type { PlacedTower, TowerPlacement } from '../game/towers';
import { swiftRound } from '../game/navigation';
import type { HudCanvas, Point, Rect } from './layout';

export type MenuButton = { id: string; frame: Rect; art: string; icon: string; label: string; cost: number | null;
  disabled: boolean; armed: boolean; affordable: boolean; progress: number | null; details: { name: string; description: string } | null };
export const centered = (p: Point, width: number, height = width): Rect => ({ x: p.x - width / 2, y: p.y - height / 2, width, height });
export function slotTarget(point: Point, view: HudCanvas, presentation: Presentation, slot: { width: number; height: number }) {
  const g = presentation.towerGeometry;
  return centered(view.point(point.x, point.y), Math.max(g.tapMinimum, slot.width * view.scale * g.tapMargin), Math.max(g.tapMinimum, slot.height * view.scale * g.tapMargin));
}
export function menuSeat(index: number, count: number, center: Point, radius: number): Point {
  const angle = (90 - 360 * index / Math.max(count, 1)) * Math.PI / 180;
  return { x: center.x + radius * Math.cos(angle), y: center.y - radius * Math.sin(angle) };
}
export function towerSprite(tower: PlacedTower, tuning: TowerTier, view: HudCanvas, art: Manifest, presentation: Presentation, heading: number, seconds: number) {
  const profile = presentation.towers[tower.kind], sprite = profile.tiers[`${tower.level}:${tower.branch}`]!;
  if (!sprite) throw new Error(`Missing native tower artwork: ${tower.kind}:${tower.level}:${tower.branch}`);
  const key = sprite.atlas ?? sprite.art, asset = requireImage(art, key), g = presentation.towerGeometry;
  const columns = sprite.atlas ? g.atlasColumns : 1, rows = sprite.atlas ? g.atlasRows : 1;
  const width = asset.width / columns, height = asset.height / rows;
  const frameCount = columns * rows, frame = ((swiftRound(-heading / 360 * frameCount) % frameCount) + frameCount) % frameCount;
  const h = tuning.has_demolition_charge ? view.scale * view.canvas.slot_width * height / width : resolveHeight(profile.height, view.playArea.height);
  const base = view.point(tower.position.x, tower.position.y + g.artworkLift), lift = resolveHeight(g.baseLift, view.playArea.height);
  const pulse = tuning.has_demolition_charge && tower.charge === null ? 1 + .12 * (1 - Math.cos(2 * Math.PI * Math.max(0,seconds) / 1.4)) / 2 : 1;
  const rect = { x: base.x - h * width / height / 2, y: base.y - h * .8 + lift, width: h * width / height, height: h };
  return { key, frame: sprite.atlas ? String(frame) : undefined,
    rect: { x: base.x - rect.width * pulse / 2, y: rect.y + rect.height * (1 - pulse), width: rect.width * pulse, height: rect.height * pulse } };
}
export function pathDetails(path: UpgradePath, purchased: number) {
  const next = path.ranks.find(r => r.rank === purchased + 1), acquired = path.ranks.filter(r => r.rank <= purchased).map(r => r.rank_description).join(' ');
  return { name: `${path.path_name} · ${next?.rank ?? path.ranks.length}/${path.ranks.length}`,
    description: `${path.path_description}\n\n${next ? `${next.cost} coins · ${next.rank_description}` : 'Fully upgraded.'}${acquired ? `\n\nPurchased: ${acquired}` : ''}` };
}
function tierDetails(tier: TowerTier) {
  const overview = tier.upgrades.map(p => `${p.path_name}: ${p.path_description}\n${p.ranks.map(r => `${r.rank}/${p.ranks.length} — ${r.cost} coins: ${r.rank_description}`).join('\n')}`).join('\n\n');
  return { name: tier.tower_name, description: tier.tower_description + (overview ? `\n\n${overview}` : '') };
}
export function towerMenuPlan(towers: TowerPlacement, view: HudCanvas, presentation: Presentation) {
  const slot = towers.content.slots.find(s => s.index === towers.selected);
  if (!slot || towers.placement) return null;
  const center = view.point(slot.x, slot.y), h = view.playArea.height, g = presentation.towerGeometry, side = h * g.button;
  const buttons: MenuButton[] = [], current = towers.current;
  const add = (id: string, point: Point, size: number, art: string, icon: string, label: string, cost: number | null,
    disabled: boolean, progress: number | null, details: MenuButton['details']) => {
    buttons.push({ id, frame: centered(point,size), art, icon, label, cost, disabled, progress, details,
      armed: towers.armed === id && cost !== null, affordable: cost === null || towers.money >= cost });
  };
  if (!current) for (const kind of towerKind.options) {
    const p = presentation.towers[kind], tier = towers.base(kind), available = towers.maxLevel(kind) >= 1;
    add(`build:${kind}`, { x: center.x + p.buildCenter.x * h, y: center.y + p.buildCenter.y * h }, side,
      p.frame, available ? p.icon : 'tower_locked_icon', tier.tower_name, available ? towers.cost(kind) : null, !available, null, tierDetails(tier));
  } else {
    const profile = presentation.towers[current.kind], offers = towers.offers, paths = towers.paths, tuning = towers.tuning(current);
    const hasPlacement = current.rally !== null || tuning.has_demolition_charge || tuning.has_engineer_obstacles;
    const upgradeCount = tuning.has_demolition_charge ? offers.length : Math.max(1, offers.length), count = upgradeCount + (hasPlacement ? 1 : 0);
    const place = (i: number) => {
      if (tuning.has_engineer_obstacles && offers.length) {
        const seat = offers.length === 1 ? 0 : offers.length === 2 ? (i === 0 ? 3 : 1) : [3,0,1][i]!;
        return menuSeat(seat,4,center,h*g.ring);
      }
      return menuSeat(i,count,center,h*g.ring);
    };
    if (paths.length) for (const p of paths) {
      const rank = current.ranks[p.id] ?? 0, next = p.ranks.find(r => r.rank === rank + 1);
      add(`path:${p.id}`, menuSeat(p.slot === 1 ? 3 : 1,4,center,h*g.ring),side,profile.frame,p.icon_name,p.path_name,next?.cost ?? null,false,rank/p.ranks.length,pathDetails(p,rank));
    } else if (!offers.length && !tuning.has_demolition_charge) add('max',place(0),side,profile.frame,profile.icon,'Fully upgraded',null,true,null,null);
    else offers.forEach((offer,i) => {
      const native = profile.tiers[`${offer.tier.tower_level}:${offer.branch}`]!;
      add(`tier:${offer.branch}`,place(i),side,profile.frame,native.icon ?? (offers.length > 1 ? native.art : profile.icon),
        offer.tier.tower_name,offer.cost,false,null,tierDetails(offer.tier));
    });
    if (hasPlacement) {
      const fixed = paths.length > 0 || tuning.has_demolition_charge || tuning.has_engineer_obstacles;
      add('placement',menuSeat(fixed ? 1 : upgradeCount,fixed ? 2 : count,center,h*g.seat),side*.9702,
        'tower_menu_square_frame','rally_point_icon',tuning.has_demolition_charge ? 'Place charge' : tuning.has_engineer_obstacles ? 'Move abatis' : 'Set rally point',null,false,null,null);
    }
  }
  return { center, background: centered(center,h*g.backgroundWidth,h*g.backgroundHeight), buttons,
    selected: buttons.find(b => b.id === towers.armed), iconInset: g.iconInset };
}

// Port of TowerLabelPlacement.resolve; the browser measures its actual text.
export function labelPlacement(button: Rect, bounds: Rect, obstacles: Rect[], measure: (width: number) => number) {
  const safe = { x: bounds.x+6, y: bounds.y+6, width: bounds.width-12, height: bounds.height-12 };
  if (safe.width <= 0 || safe.height <= 0) return null;
  const right = (r: Rect) => r.x+r.width, bottom = (r: Rect) => r.y+r.height;
  const blockers = obstacles.map(r => ({ x:r.x-4,y:r.y-4,width:r.width+8,height:r.height+8 }));
  const intersect = (a: Rect,b: Rect) => a.x < right(b) && right(a) > b.x && a.y < bottom(b) && bottom(a) > b.y;
  const scroll: { frame: Rect; contentHeight: number }[] = [];
  for (const side of ['top','right','left','bottom'] as const) {
    const area = { ...safe };
    if (side === 'top') area.height = Math.max(0,button.y-8-safe.y);
    if (side === 'right') { area.x = Math.max(safe.x,right(button)+8); area.width = Math.max(0,right(safe)-area.x); }
    if (side === 'left') area.width = Math.max(0,button.x-8-safe.x);
    if (side === 'bottom') { area.y = Math.max(safe.y,bottom(button)+8); area.height = Math.max(0,bottom(safe)-area.y); }
    if (area.width < 160 || area.height < 60) continue;
    for (const width of [Math.min(320,area.width),Math.min(440,area.width),Math.min(240,area.width)]) {
      const height = Math.ceil(measure(width));
      const fit = (visible: number) => {
        if (width > area.width || visible > area.height) return undefined;
        const vertical = side === 'top' || side === 'bottom', low = vertical ? area.x : area.y;
        const high = vertical ? right(area)-width : bottom(area)-visible, ideal = vertical ? button.x+(button.width-width)/2 : button.y+(button.height-visible)/2;
        return [ideal,low,high,...blockers.flatMap(b => vertical ? [b.x-width,right(b)] : [b.y-visible,bottom(b)])]
          .map(v => Math.min(Math.max(v,low),high)).sort((a,b) => Math.abs(a-ideal)-Math.abs(b-ideal))
          .map(offset => ({ width,height:visible, x: vertical ? offset : side === 'right' ? area.x : right(area)-width,
            y: vertical ? side === 'top' ? bottom(area)-visible : area.y : offset })).find(r => !blockers.some(b => intersect(r,b)));
      };
      const full = fit(height); if (full) return { frame:full,contentHeight:height };
      for (const visible of [Math.min(height,area.height),...blockers.flatMap(b => [Math.min(height,b.y-area.y),Math.min(height,bottom(area)-bottom(b))])])
        if (visible >= 60 && visible < height) { const frame=fit(visible); if(frame) scroll.push({frame,contentHeight:height}); }
    }
  }
  return scroll.reduce<typeof scroll[number] | null>((best,p) => !best || p.frame.height/p.contentHeight > best.frame.height/best.contentHeight ? p : best,null);
}
