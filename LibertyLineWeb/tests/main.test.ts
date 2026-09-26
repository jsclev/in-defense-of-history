// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ start: vi.fn(), dispose: vi.fn(), sql: vi.fn(), platform: vi.fn(), render: vi.fn() }));
vi.mock('../src/app', () => ({ startApplication: mocks.start }));
vi.mock('../src/platform/platform', () => ({ platform: mocks.platform }));
vi.mock('../src/game/renderer', () => ({ render: mocks.render }));
vi.mock('sql.js', () => ({ default: mocks.sql }));
afterEach(() => { vi.unstubAllGlobals(); vi.clearAllMocks(); });

it('wires the host, bundled WASM, renderer and page cleanup', async () => {
  vi.resetModules(); vi.stubGlobal('__PLATFORM__', 'website');
  window.fetch = vi.fn(); mocks.platform.mockReturnValue({}); mocks.start.mockResolvedValue(mocks.dispose);
  await import('../src/main');
  await vi.waitFor(() => expect(mocks.start).toHaveBeenCalledOnce());
  const deps = mocks.start.mock.calls[0]![0];
  expect(deps.document).toBe(document); expect(deps.render).toBe(mocks.render);
  await deps.sql(); expect(mocks.sql.mock.calls[0]![0].locateFile()).toContain('sql-wasm.wasm');
  window.dispatchEvent(new Event('pagehide')); expect(mocks.dispose).toHaveBeenCalledOnce();
});
it('shows an SDK bootstrap failure instead of leaving an empty screen', async () => {
  vi.resetModules(); vi.stubGlobal('__PLATFORM__', 'facebook');
  document.body.innerHTML = '<p id="error" hidden></p>';
  window.fetch = vi.fn(); mocks.platform.mockImplementation(() => { throw new Error('SDK missing'); });
  await import('../src/main');
  expect(document.getElementById('error')!.hidden).toBe(false);
  expect(document.getElementById('error')!.textContent).toBe('SDK missing');
});
