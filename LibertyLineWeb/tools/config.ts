import { defineConfig, type UserConfig } from 'vite';
import type { Target } from '../src/platform/platform';
import { generated, project } from './paths';
import { join } from 'node:path';

export function webConfig(target: string): UserConfig {
  if (target !== 'website' && target !== 'facebook') throw new Error(`Unknown build target: ${target}`);
  const platform: Target = target;
  return defineConfig({
    root: project, base: './', publicDir: generated,
    cacheDir: join(process.env.TMPDIR || '/tmp', 'liberty-line-vite-cache'),
    define: { __PLATFORM__: JSON.stringify(platform) },
    build: { outDir: join(project, 'dist', target), emptyOutDir: true,
      rollupOptions: { output: { manualChunks: { phaser: ['phaser'], sqlite: ['sql.js'] } } } },
    plugins: [{
      name: 'instant-games-platform',
      transformIndexHtml() {
        return target === 'facebook' ? [{ tag: 'script', attrs: { src: 'https://connect.facebook.net/en_US/fbinstant.8.0.js' }, injectTo: 'head' }] : [];
      },
      generateBundle() {
        if (target === 'facebook') this.emitFile({ type: 'asset', fileName: 'fbapp-config.json',
          source: JSON.stringify({ instant_games: { platform_version: 'RICH_GAMEPLAY', navigation_menu_version: 'NAV_FLOATING' } }) });
      },
    }],
  });
}
