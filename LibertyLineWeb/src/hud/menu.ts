import type { HeroDefinition, PlayerSetting, PlayerState } from '../data/contracts';
import { requireImage, type Manifest } from '../content/schema';

export type MenuActions = { resume(): void; restart(): Promise<void>; campaign(): void; play(id: string): Promise<void>;
  setting(key: PlayerSetting, enabled: boolean): Promise<PlayerState>; heroAI(id: string, enabled: boolean): Promise<PlayerState> };
const settingLabels: Record<PlayerSetting, string> = { enemy_escape_haptics_enabled: 'Life-loss haptics',
  show_ga_solution_button: 'Watch GA solutions', debug_mode: 'Debug mode', show_debug_info: 'Simulation readout', show_debug_layout_guides: 'Layout guides' };
export function mountMenu(dialog: HTMLDialogElement, manifest: Manifest, heroes: HeroDefinition[], actions: MenuActions) {
  const document = dialog.ownerDocument;
  const get = <T extends HTMLElement>(id: string) => dialog.querySelector<T>(`#${id}`)!;
  let mode: 'pause' | 'settings' | 'campaign' | 'victory' | 'defeat' = 'pause';
  let player: PlayerState; let busy = false;
  const settings = get('settings-list'), error = get('settings-error'), title = get('title');
  get<HTMLImageElement>('settings-icon').src = requireImage(manifest, 'main_menu_settings').url;
  get<HTMLImageElement>('pause-icon').src = requireImage(manifest, 'pause_icon_glyph').url;
  function show(next: typeof mode, state: PlayerState) {
    mode = next; player = state; error.hidden = true;
    get('haptics').setAttribute('aria-pressed', String(Boolean(player.settings.enemy_escape_haptics_enabled)));
    title.textContent = next === 'settings' ? 'SETTINGS' : next === 'campaign' ? 'MAIN CAMPAIGN' : next === 'victory' ? 'VICTORY' : next === 'defeat' ? 'DEFEAT' : 'PAUSED';
    get('pause-actions').hidden = next !== 'pause'; get('campaign-actions').hidden = next !== 'campaign';
    get('outcome-actions').hidden = next !== 'victory' && next !== 'defeat'; get('settings-actions').hidden = next !== 'settings';
    if (next === 'settings') drawSettings();
    if (!dialog.open) dialog.showModal();
    get<HTMLButtonElement>(next === 'settings' ? 'settings-done' : next === 'campaign' ? 'play-level' : next === 'pause' ? 'resume' : 'retry-level').focus();
  }
  function drawSettings() {
    settings.replaceChildren();
    const toggle = (name: string, enabled: boolean, key: string, hero: boolean) => {
      const label = document.createElement('label'), text = document.createElement('span'), input = document.createElement('input');
      input.type = 'checkbox'; input.checked = enabled; input.dataset[hero ? 'hero' : 'setting'] = key;
      text.textContent = name; label.append(text, input); settings.append(label);
    };
    for (const [key, label] of Object.entries(settingLabels)) toggle(label, Boolean(player.settings[key as PlayerSetting]), key, false);
    for (const hero of heroes.filter(h => player.unlockedHeroes.some(u => u.hero_id === h.id)))
      toggle(`${hero.short_name} — Hero AI`, Boolean(player.heroControls.find(c => c.hero_id === hero.id)!.ai_enabled), hero.id, true);
  }
  async function run(action: () => Promise<void>) {
    if (busy) return;
    busy = true; dialog.setAttribute('aria-busy', 'true');
    try { await action(); }
    catch (reason) { error.textContent = reason instanceof Error ? reason.message : String(reason); error.hidden = false; }
    finally { busy = false; dialog.removeAttribute('aria-busy'); }
  }
  function click(event: Event) {
    const button = (event.target as Element).closest('button'); if (!button || busy) return;
    switch (button.id) {
      case 'resume': dialog.close(); actions.resume(); break;
      case 'settings': show('settings', player); break;
      case 'settings-done': show('pause', player); break;
      case 'restart': case 'retry-level': void run(actions.restart); break;
      case 'campaign': case 'outcome-campaign': actions.campaign(); show('campaign', player); break;
      case 'play-level': void run(() => actions.play(get<HTMLSelectElement>('level').value)); break;
      case 'haptics': void run(async () => {
        player = await actions.setting('enemy_escape_haptics_enabled', !player.settings.enemy_escape_haptics_enabled);
        get('haptics').setAttribute('aria-pressed', String(Boolean(player.settings.enemy_escape_haptics_enabled)));
      }); break;
    }
  }
  function change(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.type !== 'checkbox') return;
    if (busy) { input.checked = !input.checked; return; }
    const value = input.checked; input.checked = !value; input.disabled = true;
    void run(async () => {
      try {
        player = input.dataset.hero ? await actions.heroAI(input.dataset.hero, value) : await actions.setting(input.dataset.setting as PlayerSetting, value);
        input.checked = value;
      } finally { input.disabled = false; }
    });
  }
  function cancel(event: Event) {
    event.preventDefault(); if (busy) return;
    if (mode === 'settings') show('pause', player);
    else if (mode === 'pause') { dialog.close(); actions.resume(); }
  }
  dialog.addEventListener('click', click); dialog.addEventListener('change', change); dialog.addEventListener('cancel', cancel);
  return { show, close: () => { if (dialog.open) dialog.close(); }, destroy: () => {
    dialog.removeEventListener('click', click); dialog.removeEventListener('change', change); dialog.removeEventListener('cancel', cancel);
    if (dialog.open) dialog.close();
  } };
}
