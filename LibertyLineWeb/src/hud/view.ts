import { requireImage, type Manifest } from '../content/schema';
import { buttonRow, hudSizing, inset, location, statsLayout, waveLayout, type HudCanvas, type Rect } from './layout';
import { regionPath } from './regions';
import type { HudContent, HudControl, HudInput, HudState } from './state';

// Artwork keys match the native HUD views. Portrait keys come only from the DAO.
export const hudArt = {
  frame: 'hud_misc_sack_blue_frame', locked: 'tower_locked_icon', reinforcements: 'action_icon_call_reinforcements',
  speed: 'speed_up_icon_glyph', pause: 'pause_icon_glyph', inventory: 'hud_misc_sack',
  lives: 'lives_icon_05', money: 'money_icon_12', wave: 'hud_call_wave', confirmWave: 'hud_call_wave_confirm', settings: 'main_menu_settings',
};
export function hudImageKeys(state: HudState) { return [...new Set([...Object.values(hudArt), ...state.heroes.map(h => h.portrait)])]; }
export function place(node: HTMLElement | SVGElement, rect: Rect) {
  for (const [key, value] of Object.entries({ left: rect.x, top: rect.y, width: rect.width, height: rect.height })) {
    const css = `${value}px`;
    if (node.style.getPropertyValue(key) !== css) node.style.setProperty(key, css);
  }
}
// PaintedHeroHUDFrameOutline, normalized from the canonical portrait outline.
const portraitOutline = [[86,2],[194,2],[214,20],[1038,20],[1060,2],[1168,2],[1240,74],[1240,188],[1223,209],[1223,998],
  [1240,1020],[1240,1157],[1168,1228],[1056,1228],[1034,1207],[212,1207],[194,1228],[86,1228],[14,1157],[14,1020],[33,998],[33,210],[14,188],[14,74]];
const clipPortrait = `polygon(${portraitOutline.map(([x, y]) => `${(x! - 14) / 1226 * 100}% ${(y! - 2) / 1226 * 100}%`).join(',')})`;

export function mountHud(host: HTMLElement, manifest: Manifest, content: HudContent, input: HudInput = {}) {
  const document = host.ownerDocument;
  const root = document.createElement('div'); root.className = 'hud'; root.setAttribute('aria-label', 'Battle HUD'); host.append(root);
  // A sibling stacking context lets tower menus cover map-positioned wave
  // controls without covering persistent controls such as reinforcements.
  const waves = document.createElement('div'); waves.className = 'wave-controls'; host.append(waves);
  const cursors = new Map<HTMLElement, number>();
  const node = <K extends keyof HTMLElementTagNameMap>(tag: K, className: string, parent: HTMLElement = root) => {
    const index = cursors.get(parent) ?? 0; cursors.set(parent, index + 1);
    let result = parent.children[index] as HTMLElementTagNameMap[K] | undefined;
    if (!result || result.tagName.toLowerCase() !== tag) {
      const created = document.createElement(tag);
      if (result) result.replaceWith(created); else parent.append(created); result = created;
    }
    result.className = className; result.style.cssText = ''; return result;
  };
  const image = (key: string, rect: Rect, parent: HTMLElement) => {
    const art = node('img', 'hud-image', parent); const url = requireImage(manifest, key).url;
    if (art.getAttribute('src') !== url) art.src = url; art.alt = ''; art.draggable = false;
    place(art, rect); return art;
  };
  const paintedFrame = (rect: Rect, parent: HTMLElement) => {
    // PaintedHUDButtonFrame.frameRim: normalize the visible rim, not the canvas.
    image(hudArt.frame, { x: -rect.width * 14 / 357, y: -rect.height * 15 / 348,
      width: rect.width * 384 / 357, height: rect.height * 384 / 348 }, parent).style.objectFit = 'fill';
  };
  const icon = (key: string, rect: Rect, parent: HTMLElement) => {
    const margin = (1 - hudSizing.paintedButtonIconFraction) / 2;
    return image(key, inset(rect, rect.width * margin, rect.height * margin), parent);
  };
  const control = (id: string, label: string, rect: Rect, action: (() => void) | undefined, active: boolean, parent = root) => {
    const button = node('button', 'hud-button', parent); button.type = 'button'; button.dataset.control = id;
    button.setAttribute('aria-label', label); button.disabled = !action || state.acceptsInput === false; button.classList.toggle('is-active', active);
    button.setAttribute('aria-pressed', String(active));
    button.style.setProperty('--side', `${rect.width}px`); place(button, rect);
    button.onclick = action ?? null;
    return button;
  };
  let currentView: HudCanvas;
  let state = content.state;
  const sections = new Map<string, { inputs: unknown[]; start: number; count: number }>();
  function draw(view: HudCanvas, next: HudState = state, force = true) {
    currentView = view; state = next;
    cursors.clear();
    // Each control observes only its own inputs. Skipping a section also retains
    // its descendant nodes and styles, including a button held by a pointer.
    const section = (key: string, inputs: unknown[], render: () => void, parent = root) => {
      const previous = sections.get(key), start = cursors.get(parent) ?? 0;
      cursors.set(parent, start);
      if (!force && previous && previous.start === start && inputs.length === previous.inputs.length && inputs.every((v, i) => v === previous.inputs[i])) {
        cursors.set(parent, start + previous.count); return;
      }
      render(); sections.set(key, { inputs, start, count: (cursors.get(parent) ?? 0) - start });
    };
    const active = (id: HudControl) => state.activated.includes(id);
    const loc = (section: Parameters<typeof location>[1]) => location(content.player.hud, section);
    const heroes = buttonRow(view, loc('hero_bar'), 3);
    for (let i = 0; i < 2; i++) {
      const hero = state.heroes[i], id = i === 0 ? 'primaryHero' : 'secondaryHero';
      section(id, [loc('hero_bar'), hero?.id, hero?.portrait, hero?.label, hero?.isAvailable, hero?.isSelected, active(id), state.acceptsInput], () => {
      const rect = heroes.buttons[i]!, local = { ...rect, x: 0, y: 0 };
      const button = control(id, hero?.label ?? `No ${i === 0 ? 'primary' : 'secondary'} hero chosen`, rect,
        hero?.isAvailable ? input.activate?.[id] : undefined, hero?.isSelected === true || active(id));
      if (hero) {
        const portrait = image(hero.portrait, local, button); portrait.style.clipPath = clipPortrait;
        if (!hero.isAvailable) portrait.style.filter = 'grayscale(1)';
      } else {
        paintedFrame(local, button); icon(hudArt.locked, local, button).style.filter = 'grayscale(1)';
      }
      });
    }
    section('reinforcements', [loc('hero_bar'), state.canCallReinforcements, state.isPlacingReinforcements, active('reinforcements'),
      state.acceptsInput, state.reinforcementRemaining, state.reinforcementSeconds], () => {
    const reinforcement = heroes.buttons[2]!, rLocal = { ...reinforcement, x: 0, y: 0 };
    const call = control('reinforcements', 'Call reinforcements', reinforcement,
      state.canCallReinforcements ? input.activate?.reinforcements : undefined, state.isPlacingReinforcements || active('reinforcements'));
    paintedFrame(rLocal, call); icon(hudArt.reinforcements, rLocal, call);
    call.setAttribute('aria-description', state.isPlacingReinforcements ? 'Selected' : state.reinforcementRemaining === 0 ? 'Ready' : `${state.reinforcementSeconds} seconds remaining`);
    if (state.reinforcementRemaining > 0) {
      const track = node('div', 'hud-cooldown', call); place(track, inset(rLocal, rLocal.width * 0.11, rLocal.height * 0.11));
      track.style.borderRadius = `${rLocal.width * 0.04}px`;
      node('div', 'hud-cooldown-shade', track).style.height = `${state.reinforcementRemaining * 100}%`;
    }
    });
    const masters = buttonRow(view, loc('master_controls'), 2);
    (['speed', 'pause'] as const).forEach((id, i) => {
      section(id, [loc('master_controls'), active(id), state.acceptsInput, id === 'speed' ? state.speed : state.isPaused], () => {
      const rect = masters.buttons[i]!, local = { ...rect, x: 0, y: 0 };
      const button = control(id, id === 'speed' ? 'Speed up' : 'Pause level', rect, input.activate?.[id], active(id) || id === 'pause' && state.isPaused);
      if (id === 'speed' && state.speed !== undefined) button.setAttribute('aria-description', `${state.speed} times normal speed`);
      paintedFrame(local, button); image(hudArt[id], local, button);
      });
    });
    section('inventory', [loc('misc_view'), active('inventory'), state.acceptsInput], () => {
    const misc = buttonRow(view, loc('misc_view'), 1).buttons[0]!, mLocal = { ...misc, x: 0, y: 0 };
    const inventory = control('inventory', 'Inventory', misc, input.activate?.inventory, active('inventory'));
    image(hudArt.frame, mLocal, inventory); icon(hudArt.inventory, mLocal, inventory);
    });

    const aspect = (key: string) => { const art = requireImage(manifest, key); return art.width / art.height; };
    const stats = statsLayout(view, loc('stats_view'), aspect(hudArt.lives), aspect(hudArt.money));
    const plate = (rect: Rect, label: string) => {
      const result = node('div', 'hud-plate'); place(result, rect); result.style.borderRadius = `${stats.radius}px`;
      result.setAttribute('role', 'status'); result.setAttribute('aria-label', label); return result;
    };
    const text = (value: string, rect: Rect, parent: HTMLElement) => {
      const result = node('span', 'hud-number', parent); result.textContent = value; result.setAttribute('aria-hidden', 'true');
      place(result, rect); result.style.fontSize = `${stats.font}px`; return result;
    };
    const counter = (key: string, value: string, label: string, row: typeof stats.lives) => {
      const bg = plate(row.plate, label);
      image(key, { ...row.icon, x: row.icon.x - row.plate.x, y: row.icon.y - row.plate.y }, bg);
      text(value, { ...row.value, x: row.value.x - row.plate.x, y: row.value.y - row.plate.y }, bg);
    };
    section('lives', [loc('stats_view'), state.lives], () => counter(hudArt.lives, String(state.lives), `Lives: ${state.lives}`, stats.lives));
    const money = state.money >= 1000 ? `${Math.floor(state.money / 1000)},${String(state.money % 1000).padStart(3, '0')}` : String(state.money);
    section('money', [loc('stats_view'), state.money], () => counter(hudArt.money, money, `Money: ${state.money}`, stats.money));
    section('wave-count', [loc('stats_view'), state.wave, state.waveCount], () => {
    const wave = plate(stats.wave, `Wave ${state.wave} of ${state.waveCount}`);
    text(`${state.wave} of ${state.waveCount}`, { ...stats.wave, x: 0, y: 0 }, wave).style.justifyContent = 'center';
    });
    section('wave-buttons', [state.acceptsInput, state.nextWave, state.countdownSeconds, state.selectedWave?.x, state.selectedWave?.y,
      ...state.callWavePositions.flatMap(p => [p.x, p.y])], () => {
    state.callWavePositions.forEach((point, i) => {
      const selected = state.selectedWave?.x === point.x && state.selectedWave.y === point.y;
      const layout = waveLayout(view, point), local = { ...layout.frame, x: 0, y: 0 };
      const button = control(`wave-${i}`, `${selected ? 'Confirm call' : 'Select'} wave ${state.nextWave}`, layout.frame,
        input.callWave ? () => input.callWave!(point) : undefined, false, waves);
      button.classList.add('hud-wave');
      button.setAttribute('aria-description', state.countdownSeconds === null ? 'Waiting for you to start' : `Starts automatically in ${state.countdownSeconds} seconds`);
      const art = node('div', `hud-wave-art${selected ? ' is-selected' : ''}`, button);
      if (selected) image(hudArt.confirmWave, local, art).style.clipPath = 'circle(49.4%)';
      else {
        node('div', 'hud-wave-background', art);
        image(hudArt.wave, local, art).classList.add('hud-wave-horn');
        image(hudArt.wave, local, art).classList.add('hud-wave-rim');
      }
      if (state.countdownSeconds !== null) {
        const countdown = node('span', 'hud-wave-countdown', button); countdown.textContent = `${state.countdownSeconds}s`;
        countdown.style.fontSize = `${layout.font}px`; countdown.style.padding = `${layout.verticalPadding}px ${layout.horizontalPadding}px`;
      }
    });
    }, waves);
    section('guides', [content.player.settings.show_debug_layout_guides], () => {
      const holder = node('div', 'hud-guide-layer');
      holder.replaceChildren(...(content.player.settings.show_debug_layout_guides ? [guides(document, view)] : []));
    });
    // Reuse live buttons across ticks: replacing a button between pointerdown
    // and pointerup loses clicks and restarts the call-wave pulse animation.
    for (const [parent, used] of cursors) while (parent.children.length > used) parent.lastElementChild!.remove();
  }
  return { draw, update: (next: HudState, player = content.player) => {
    content.player = player; draw(currentView, next, false);
  }, destroy: () => { root.remove(); waves.remove(); } };
}

function guides(document: Document, view: HudCanvas) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.classList.add('hud-guides'); svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('viewBox', `0 0 ${view.physicalRect.width} ${view.physicalRect.height}`);
  const path = (d: string, color: string, dash: string, width = 3) => {
    const p = document.createElementNS(svg.namespaceURI, 'path'); p.setAttribute('d', d); p.setAttribute('fill', 'none');
    p.setAttribute('stroke', color); p.setAttribute('stroke-width', String(width)); p.setAttribute('stroke-dasharray', dash); svg.append(p);
  };
  path(regionPath({ bounds: inset(view.playArea, 1, 1), cuts: [] }), 'white', '', 2);
  path(regionPath({ bounds: inset(view.physicalRect, 1.5, 1.5), cuts: [] }), 'rgb(255,41,41)', '16 9');
  path(regionPath({ bounds: inset(view.safeRect, 1.5, 1.5), cuts: [] }), 'rgb(46,255,84)', '16 9');
  path(regionPath({ bounds: view.bounds, cuts: Object.values(view.corners) }), 'rgb(255,204,0)', '16 9');
  path(regionPath(view.path), 'magenta', '7.935 10'); path(regionPath(view.tap), 'cyan', '7.2 4.8');
  path(regionPath(view.slot), 'rgba(0,0,255,.85)', '5 4');
  return svg;
}
