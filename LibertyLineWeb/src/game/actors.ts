import { requireImage, type Manifest } from '../content/schema';
import { resolveHeight, type Presentation } from '../content/presentation';
import type { HudCanvas, Point } from '../hud/layout';
import { inRegion } from '../hud/regions';
import type { Actor } from './session';

export function actorPlan(actor: Actor, view: HudCanvas, art: Manifest, presentation: Presentation) {
  const image = requireImage(art, actor.key), height = resolveHeight(actor.profile ? actor.profile.height : presentation.walker, view.playArea.height);
  const width = height * image.width / image.height, foot = view.point(actor.position.x, actor.position.y);
  const inset = actor.profile ? height * actor.profile.groundInset : 0;
  const frame = { x: foot.x - width / 2, y: foot.y - height + inset, width, height };
  const healthWidth = resolveHeight(presentation.healthWidth, view.playArea.height), healthHeight = resolveHeight(presentation.healthHeight, view.playArea.height);
  const healthOffset = { x: -healthWidth / 2, y: -height - resolveHeight(presentation.labelLift, view.playArea.height) - healthHeight / 2 };
  const selectionOffsetY = -height * .1;
  return { ...actor, frame, foot, depth: actor.kind === 'hero' ? 19 : 11 + foot.y / (view.physicalRect.height + height),
    healthOffset, selectionOffsetY,
    healthRect: { x: foot.x + healthOffset.x, y: foot.y + healthOffset.y,
      width: healthWidth, height: healthHeight },
    selection: { x: foot.x, y: foot.y + selectionOffsetY, radius: height * .4, width: height * .054 },
    tapRect: { x: foot.x - Math.max(44, width) / 2, y: foot.y - height / 2 + inset - Math.max(44, height) / 2,
      width: Math.max(44, width), height: Math.max(44, height) },
  };
}
export function destination(view: HudCanvas, point: Point): Point | null {
  return inRegion({ bounds: view.path.bounds, cuts: [...view.path.cuts, ...Object.values(view.corners)] }, point) ? view.inverse(point.x, point.y) : null;
}
