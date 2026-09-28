import type Phaser from 'phaser';

export type ImagePlacement = { key: string; frame?: string; x: number; y: number; width: number; height: number;
  originX: number; originY: number; depth: number; rotation?: number; alpha?: number };

// Phaser's texture setter resets frame size/origin; its depth setter always
// queues a sort. Keep a view-only snapshot of the last applied properties.
export class ImageUpdates {
  private readonly previous = new WeakMap<Phaser.GameObjects.Image, ImagePlacement>();
  apply(image: Phaser.GameObjects.Image, next: ImagePlacement) {
    const old = this.previous.get(image), texture = !old || old.key !== next.key || old.frame !== next.frame;
    if (texture) image.setTexture(next.key, next.frame);
    if (texture || old.originX !== next.originX || old.originY !== next.originY) image.setOrigin(next.originX, next.originY);
    if (!old || old.x !== next.x || old.y !== next.y) image.setPosition(next.x, next.y);
    if (texture || old.width !== next.width || old.height !== next.height) image.setDisplaySize(next.width, next.height);
    if (!old || old.depth !== next.depth) image.setDepth(next.depth);
    if (!old || old.rotation !== next.rotation) image.setRotation(next.rotation ?? 0);
    if (!old || old.alpha !== next.alpha) image.setAlpha(next.alpha ?? 1);
    this.previous.set(image, next);
  }
}
