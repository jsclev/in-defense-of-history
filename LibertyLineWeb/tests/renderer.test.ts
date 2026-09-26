// @vitest-environment jsdom
import { beforeAll, beforeEach, expect, it, vi } from 'vitest';
import { authored, geometry, testManifest } from './fixtures';
import { readSlots } from '../src/content/geometry';
import { battlefieldPlan, type Battlefield } from '../src/game/battlefield';

const fake = vi.hoisted(() => ({ game: undefined as unknown, scene: undefined as unknown, fail: false }));
vi.mock('phaser', async () => {
  const { EventEmitter } = await import('node:events');
  class Scene {
    scale = Object.assign(new EventEmitter(), { width: 800, height: 450 });
    events = new EventEmitter();
    load = Object.assign(new EventEmitter(), { image: vi.fn() });
    children = { removeAll: vi.fn() };
    add = { image: vi.fn(() => ({ setOrigin: vi.fn().mockReturnThis(), setDisplaySize: vi.fn().mockReturnThis(), setDepth: vi.fn().mockReturnThis() })) };
    preload() {} create() {}
  }
  class Game {
    destroy = vi.fn();
    constructor(config: { scene: (new () => Scene)[] }) {
      fake.game = this;
      const scene = new config.scene[0]!(); fake.scene = scene;
      queueMicrotask(() => {
        scene.preload(); scene.load.emit('progress', 1);
        if (fake.fail) scene.load.emit('loaderror', { key: 'broken-image' });
        scene.create();
      });
    }
  }
  return { default: { Scene, Game, AUTO: 0, Scale: { RESIZE: 5 } } };
});
import { render } from '../src/game/renderer';
let battle: Battlefield;
beforeAll(async () => {
  const fixture = await authored(); const db = fixture.open();
  const level = db.levels().find(l => l.map_image_name)!;
  battle = { level, canvas: db.canvas(), manifest: testManifest(db), slots: readSlots(await geometry(level.map_image_name), level.map_image_name) };
  db.close();
});
beforeEach(() => { fake.fail = false; });
it('queues canonical textures once, redraws on resize, and detaches handlers', async () => {
  fake.fail = false; const progress = vi.fn(); const renderer = render(document.createElement('div'), battle, progress);
  await renderer.ready;
  const scene = fake.scene as { load: { image: ReturnType<typeof vi.fn> }; add: { image: ReturnType<typeof vi.fn> };
    scale: import('node:events').EventEmitter; events: import('node:events').EventEmitter };
  expect(scene.load.image).toHaveBeenCalledTimes(2);
  expect(scene.add.image).toHaveBeenCalledTimes(battle.slots.length + 1);
  scene.scale.emit('resize');
  expect(scene.add.image).toHaveBeenCalledTimes((battle.slots.length + 1) * 2);
  scene.events.emit('shutdown'); expect(scene.scale.listenerCount('resize')).toBe(0);
  expect(progress).toHaveBeenCalledWith(1);
  renderer.destroy(); expect((fake.game as { destroy: ReturnType<typeof vi.fn> }).destroy).toHaveBeenCalledWith(true);
});
it('reprojects the same scene when the viewport and browser safe insets change', async () => {
  const host = document.createElement('div');
  document.body.append(host);
  host.style.setProperty('--safe-left', '30px');
  host.style.setProperty('--safe-right', '10px');
  const renderer = render(host, battle, () => {});
  await renderer.ready;
  const game = fake.game;
  const scene = fake.scene as { add: { image: ReturnType<typeof vi.fn> }; load: { image: ReturnType<typeof vi.fn> };
    scale: import('node:events').EventEmitter & { width: number; height: number } };
  let plan = battlefieldPlan(battle, 800, 450, { left: 30, right: 10, top: 0, bottom: 0 });
  expect(scene.add.image).toHaveBeenNthCalledWith(1, plan[0]!.x, plan[0]!.y, plan[0]!.key);
  scene.add.image.mockClear();
  host.style.setProperty('--safe-left', '0px');
  host.style.setProperty('--safe-right', '0px');
  host.style.setProperty('--safe-top', '44px');
  host.style.setProperty('--safe-bottom', '34px');
  Object.assign(scene.scale, { width: 390, height: 844 });
  scene.scale.emit('resize');
  plan = battlefieldPlan(battle, 390, 844, { left: 0, right: 0, top: 44, bottom: 34 });
  plan.forEach((p, index) => {
    expect(scene.add.image).toHaveBeenNthCalledWith(index + 1, p.x, p.y, p.key);
    expect(scene.add.image.mock.results[index]!.value.setDisplaySize).toHaveBeenCalledWith(p.width, p.height);
  });
  expect(fake.game).toBe(game);
  expect(scene.load.image).toHaveBeenCalledTimes(2);
  renderer.destroy(); host.remove();
});
it('rejects malformed browser safe geometry', async () => {
  const host = document.createElement('div');
  host.style.setProperty('--safe-top', 'invalid');
  const renderer = render(host, battle, () => {});
  await expect(renderer.ready).rejects.toThrow('Invalid viewport safe insets');
  renderer.destroy();
});
it('rejects failed required textures instead of showing placeholder art', async () => {
  fake.fail = true;
  const renderer = render(document.createElement('div'), battle, () => {});
  await expect(renderer.ready).rejects.toThrow('broken-image'); renderer.destroy();
});
