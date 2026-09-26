import type { Canvas } from '../content/database';

export type Insets = { top: number; right: number; bottom: number; left: number };

// Ports Engine/Core/RuntimeCanvas.swift and Engine/Layout/LevelMapProjection.swift.
// The browser viewport is the physical screen; UI never subtracts from its size.
// Fit the SQL play rectangle inside the safe bounds. Map coordinates have +y up.
// Both point placement and art use this same projection; no per-asset offsets.
export function projection(canvas: Canvas, width: number, height: number,
  insets: Insets = { top: 0, right: 0, bottom: 0, left: 0 }) {
  if (!(width > 0 && height > 0 && Number.isFinite(width) && Number.isFinite(height))) throw new Error('Invalid viewport');
  const safeRect = { x: insets.left, y: insets.top,
    width: width - insets.left - insets.right, height: height - insets.top - insets.bottom };
  if (Object.values(insets).some(value => !Number.isFinite(value) || value < 0) || safeRect.width <= 0 || safeRect.height <= 0)
    throw new Error('Invalid viewport safe insets');
  const scale = Math.min(safeRect.width / canvas.play_area_width, safeRect.height / canvas.play_area_height);
  const playArea = { x: safeRect.x + (safeRect.width - canvas.play_area_width * scale) / 2,
    y: safeRect.y + (safeRect.height - canvas.play_area_height * scale) / 2,
    width: canvas.play_area_width * scale, height: canvas.play_area_height * scale };
  const x = playArea.x - canvas.play_area_x * scale;
  const y = playArea.y - (canvas.canvas_height - canvas.play_area_y - canvas.play_area_height) * scale;
  return {
    scale, physicalRect: { x: 0, y: 0, width, height }, safeRect, playArea,
    point: (px: number, py: number) => ({ x: x + px * scale, y: y + (canvas.canvas_height - py) * scale }),
    inverse: (px: number, py: number) => ({ x: (px - x) / scale, y: canvas.canvas_height - (py - y) / scale }),
    image: { x, y, width: canvas.canvas_width * scale, height: canvas.canvas_height * scale },
  };
}
