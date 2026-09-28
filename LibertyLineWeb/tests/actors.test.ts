import { beforeAll, expect, it } from 'vitest';
import { actorPlan } from '../src/game/actors';
import { hudCanvas } from '../src/hud/layout';
import { authored, battleSession, testManifest, type Authored } from './fixtures';
let fixture: Authored;
beforeAll(async () => { fixture = await authored(); });
it('uses native sprite clamps, ground anchors, health dimensions and hero touch targets across viewport sizes', async () => {
  const db = fixture.open();
  try {
    const session = await battleSession(db), art = testManifest(db, session.presentation), hero = session.actors(1)[0]!;
    const enemy = { ...hero, id: 'enemy-test', key: session.content.enemies[0]!.image_name, kind: 'enemy' as const, heroIndex: null, profile: null, selected: false };
    for (const [width, height] of [[360,800], [604,340], [1600,900], [3840,2160]]) {
      const view = hudCanvas(session.content.config.canvas, width!, height!,session.presentation.towerGeometry);
      const h = actorPlan(hero, view, art, session.presentation), e = actorPlan(enemy, view, art, session.presentation);
      const profile = hero.profile!, walker = session.presentation.walker;
      expect(h.frame.height).toBeGreaterThanOrEqual(profile.height.minimum); expect(h.frame.height).toBeLessThanOrEqual(profile.height.maximum);
      expect(h.frame.y + h.frame.height * (1 - profile.groundInset)).toBeCloseTo(h.foot.y);
      expect(h.tapRect.width).toBeGreaterThanOrEqual(44); expect(h.tapRect.height).toBeGreaterThanOrEqual(44);
      expect(e.frame.height).toBeGreaterThanOrEqual(walker.minimum); expect(e.frame.height).toBeLessThanOrEqual(walker.maximum);
      expect(e.frame.y + e.frame.height).toBeCloseTo(e.foot.y); expect(e.depth).toBeLessThan(h.depth);
      expect(e.healthRect.width).toBe(h.healthRect.width); expect(e.healthRect.height).toBe(h.healthRect.height);
      expect(e.healthRect.y + e.healthRect.height / 2).toBeLessThan(e.frame.y);
    }
  } finally { db.close(); }
});
