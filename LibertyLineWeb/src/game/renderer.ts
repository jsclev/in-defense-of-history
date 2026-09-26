import Phaser from 'phaser';
import { battlefieldPlan, type Battlefield } from './battlefield';
import { requireImage } from '../content/schema';
import type { Insets } from './projection';

export interface Renderer { ready: Promise<void>; destroy(): void }
export type Render = (host: HTMLElement, battle: Battlefield, progress: (fraction: number) => void) => Renderer;

// CSS env() values are the browser equivalent of UIWindow safe-area insets.
// An unset property means the host has no platform inset (e.g. an embedded host).
function safeInsets(host: HTMLElement): Insets {
  const style = getComputedStyle(host);
  const edge = (name: string) => Number.parseFloat(style.getPropertyValue(`--safe-${name}`) || '0');
  return { top: edge('top'), right: edge('right'), bottom: edge('bottom'), left: edge('left') };
}

export const render: Render = (host, battle, progress) => {
  let resolve!: () => void;
  let reject!: (reason: unknown) => void;
  let failed = false;
  const ready = new Promise<void>((yes, no) => { resolve = yes; reject = no; });
  class BattlefieldScene extends Phaser.Scene {
    preload() {
      try {
        const keys = new Set(this.plan().map(p => p.key));
        for (const key of keys) this.load.image(key, requireImage(battle.manifest, key).url);
        this.load.on('progress', progress);
        this.load.on('loaderror', (file: { key: string }) => {
          failed = true;
          reject(new Error(`Required art failed to load: ${file.key}`));
        });
      } catch (error) { failed = true; reject(error); }
    }
    create() {
      if (failed) return;
      try {
        this.draw();
        const resize = () => this.draw();
        this.scale.on('resize', resize);
        this.events.once('shutdown', () => this.scale.off('resize', resize));
        resolve();
      } catch (error) { reject(error); }
    }
    plan() {
      return battlefieldPlan(battle, this.scale.width, this.scale.height, safeInsets(host));
    }
    draw() {
      this.children.removeAll(true);
      for (const p of this.plan()) {
        this.add.image(p.x, p.y, p.key).setOrigin(p.origin).setDisplaySize(p.width, p.height).setDepth(p.depth);
      }
    }
  }
  const game = new Phaser.Game({
    type: Phaser.AUTO, parent: host, backgroundColor: '#182822',
    scale: { mode: Phaser.Scale.RESIZE, width: host.clientWidth, height: host.clientHeight },
    render: { antialias: true }, scene: [BattlefieldScene],
    audio: { noAudio: true }, // No audio ported in this milestone.
  });
  return { ready, destroy: () => game.destroy(true) };
};
