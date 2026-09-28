import { requireImage, type Manifest } from '../content/schema';
import { resolveHeight, type Presentation } from '../content/presentation';
import type { HudCanvas, Point } from '../hud/layout';
import type { Impact, Projectile } from './combat';
import { lerp } from './navigation';
import { radians, type EnemyMorale } from './combat-math';

export function projectilePlan(p: Projectile, alpha: number, view: HudCanvas, art: Manifest, presentation: Presentation) {
  const profile = presentation.towers[p.kind].projectile, key = profile.asset;
  if (key === null) throw Error(`Missing projectile art for ${p.kind}`);
  const asset = requireImage(art, key), position = lerp(p.previous, p.position, alpha);
  const height = resolveHeight(profile.height, view.playArea.height) * (p.tuning.attack_mode === 'grapeshot' ? .45 : 1);
  return { key, ...view.point(position.x, position.y), width: height * asset.width / asset.height, height, rotation: p.heading };
}
export type Ellipse = { x: number; y: number; width: number; height: number; color: number; alpha: number; stroke: number };
export function impactPlan(impact: Impact, view: HudCanvas, presentation: Presentation, reduceMotion: boolean) {
  const point = view.point(impact.position.x, impact.position.y), radius = impact.radius * view.scale, age = impact.age;
  const shapes: Ellipse[] = [], frames: { frame: string; alpha: number }[] = [];
  const ellipse = (x: number, y: number, width: number, height: number, color: number, alpha: number, stroke = 0) =>
    shapes.push({ x: point.x + x, y: point.y + y, width, height, color, alpha, stroke });
  const explosion = presentation.explosion, duration = explosion.frameEnds.at(-1)!;
  if (impact.demolition) {
    const frame = explosion.frameEnds.findIndex(end => age < end);
    if (frame >= 0 && age >= 0) {
      if (reduceMotion) frames.push({ frame: '7', alpha: .5 * (1 - age / duration) });
      else {
        const start = frame === 0 ? 0 : explosion.frameEnds[frame - 1]!;
        const blend = frame + 1 < explosion.frameEnds.length ? (age - start) / (explosion.frameEnds[frame]! - start) : 0;
        const opacity = age < .24 ? 1 : Math.max(0, (duration - age) / (duration - .24)) ** .75;
        frames.push({ frame: String(frame), alpha: (1 - blend) * opacity });
        if (blend > 0) frames.push({ frame: String(frame + 1), alpha: blend * opacity });
        ellipse(0, 0, radius * 1.2, radius * .48, 0x302421, .3 * (1 - age / duration));
        if (age < .42) { const t = age / .42, spread = radius * (.12 + .88 * (1 - (1 - t) ** 3));
          ellipse(0, 0, 2 * spread, 2 * spread, 0xffc459, .85 * (1 - t), Math.max(2.2, radius * .043)); }
        if (age < .12) { const t = age / .12, flash = radius * (.12 + .16 * t); ellipse(0, 0, flash * 2, flash * 1.1, 0xfff2b3, 1 - t); }
      }
    }
  } else if (!reduceMotion && age < .78) {
    const t = age / .78, spread = radius * (1 - (1 - t) ** 3), puff = radius * (.10 + .14 * t);
    ellipse(0, 0, spread * 2, spread * .88, 0xf2d491, 1 - t, 1.5);
    for (let i = 0; i < 7; i++) { const angle = i * Math.PI * 2 / 7;
      ellipse(Math.cos(angle) * spread * .28, Math.sin(angle) * spread * .14 - t * radius * .1, puff * 2, puff * 1.4, 0xe0c497, .45 * (1 - t)); }
  }
  return { shapes, frames, key: explosion.asset, x: point.x, y: point.y + (.5 - explosion.anchor) * 2 * radius, side: 2 * radius };
}
// EnemyMoraleSprite: the blue arc drains over a fixed dark track at the unit's feet.
export function moralePlan(morale: EnemyMorale, foot: Point, height: number, presentation: Presentation, reduceMotion: boolean) {
  const scale = height / presentation.walker.minimum, flinch = reduceMotion ? 0 : Math.sin(Math.min(1, morale.age / .33) * Math.PI);
  const fraction = reduceMotion ? morale.fraction : morale.displayedFraction;
  return { dx: flinch * 2 * scale * morale.direction, dy: flinch * scale, rotation: radians(flinch * 9 * morale.direction),
    visible: morale.visible, x: foot.x - 5 * scale, y: foot.y - 16 * scale, radius: 10 * scale,
    trackWidth: 3.6 * scale, fillWidth: 2.2 * scale, start: radians(125), end: radians(235), fillEnd: radians(125 + 110 * fraction), fraction };
}
