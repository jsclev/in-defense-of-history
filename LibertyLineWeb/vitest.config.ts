import { defineConfig } from 'vitest/config';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export default defineConfig({
  cacheDir: join(tmpdir(), 'liberty-line-vitest-cache'),
  test: {
    include: ['tests/**/*.test.ts'],
    coverage: { provider: 'v8', reportsDirectory: join(tmpdir(), 'liberty-line-web-coverage'),
      include: ['src/**/*.ts', 'tools/**/*.ts'], exclude: ['tools/build.ts', 'tools/prepare.ts', 'tools/paths.ts'],
      reporter: ['text', 'html'], thresholds: { lines: 95, statements: 95, functions: 95, branches: 85 } },
    testTimeout: 30000, hookTimeout: 60000,
  },
});
