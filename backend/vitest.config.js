import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    globalSetup: ['./test/global-setup.js'],
    setupFiles: ['./test/setup.js'],
    include: ['test/**/*.test.js'],
    // Integration tests share one database and truncate it, so run files one at a time.
    fileParallelism: false,
    testTimeout: 20_000,
    hookTimeout: 30_000,
  },
});
