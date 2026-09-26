export type Target = 'website' | 'facebook';
export interface InstantSDK {
  initializeAsync(): Promise<void>;
  setLoadingProgress(percent: number): void;
  startGameAsync(): Promise<void>;
}
export interface Platform {
  initialize(): Promise<void>;
  progress(fraction: number): void;
  start(): Promise<void>;
}

export function platform(target: Target, sdk?: InstantSDK): Platform {
  if (target === 'website') return { initialize: async () => {}, progress: () => {}, start: async () => {} };
  if (!sdk) throw new Error('Facebook Instant Games SDK did not load');
  let phase: 'new' | 'loading' | 'playing' = 'new';
  let previousProgress = 0;
  return {
    async initialize() {
      if (phase !== 'new') throw new Error('Platform already initialized');
      await sdk.initializeAsync(); phase = 'loading';
    },
    progress(fraction) {
      if (phase !== 'loading') throw new Error('Loading progress outside initialization');
      if (!Number.isFinite(fraction)) throw new Error('Invalid loading progress');
      previousProgress = Math.max(previousProgress, Math.round(Math.max(0, Math.min(1, fraction)) * 100));
      sdk.setLoadingProgress(previousProgress);
    },
    async start() {
      if (phase !== 'loading') throw new Error('Platform must initialize before start');
      await sdk.startGameAsync(); phase = 'playing';
    },
  };
}
