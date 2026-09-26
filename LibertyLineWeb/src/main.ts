import initSqlJs from 'sql.js';
import wasmUrl from 'sql.js/dist/sql-wasm.wasm?url';
import { startApplication } from './app';
import { platform, type InstantSDK, type Target } from './platform/platform';
import { render } from './game/renderer';
import './style.css';

declare const __PLATFORM__: Target;
declare global { interface Window { FBInstant?: InstantSDK } }

async function main() {
 try {
  const dispose = await startApplication({ document, fetch: window.fetch.bind(window),
    sql: () => initSqlJs({ locateFile: () => wasmUrl }), platform: platform(__PLATFORM__, window.FBInstant), render });
  window.addEventListener('pagehide', dispose, { once: true });
 } catch (error) {
  const alert = document.getElementById('error')!;
  alert.hidden = false; alert.textContent = error instanceof Error ? error.message : String(error);
 }
}
void main();
