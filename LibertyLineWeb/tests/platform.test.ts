import { describe, expect, it, vi } from 'vitest';
import { platform } from '../src/platform/platform';

describe('one game, two hosts', () => {
  it('runs website without Facebook calls', async () => {
    const sdk = { initializeAsync: vi.fn(), startGameAsync: vi.fn(), setLoadingProgress: vi.fn() };
    const host = platform('website', sdk);
    await host.initialize(); host.progress(1); await host.start();
    expect(sdk.initializeAsync).not.toHaveBeenCalled();
  });
  it('initializes, reports monotonic progress, then starts Facebook', async () => {
    const sdk = { initializeAsync: vi.fn().mockResolvedValue(undefined), startGameAsync: vi.fn().mockResolvedValue(undefined), setLoadingProgress: vi.fn() };
    const host = platform('facebook', sdk);
    await expect(host.start()).rejects.toThrow();
    await host.initialize();
    host.progress(-1); host.progress(0.6); host.progress(0.3); host.progress(2);
    expect(sdk.setLoadingProgress.mock.calls.flat()).toEqual([0,60,60,100]);
    await host.start();
    expect(() => host.progress(1)).toThrow();
    await expect(host.start()).rejects.toThrow();
    await expect(host.initialize()).rejects.toThrow();
  });
  it('fails missing SDK and rejected initialization without website fallback', async () => {
    expect(() => platform('facebook')).toThrow('SDK');
    const sdk = { initializeAsync: vi.fn().mockRejectedValue(new Error('denied')), startGameAsync: vi.fn(), setLoadingProgress: vi.fn() };
    const host = platform('facebook', sdk);
    await expect(host.initialize()).rejects.toThrow('denied');
    expect(sdk.startGameAsync).not.toHaveBeenCalled();
  });
  it('propagates platform start errors and rejects nonfinite progress', async () => {
    const host = platform('facebook', { initializeAsync: async () => {}, startGameAsync: async () => { throw new Error('start denied'); }, setLoadingProgress: () => {} });
    await host.initialize();
    expect(() => host.progress(NaN)).toThrow();
    await expect(host.start()).rejects.toThrow('start denied');
  });
});
