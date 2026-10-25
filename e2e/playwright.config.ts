import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: /lia-sugestao\.spec\.ts/,
  workers: 1,
  retries: 0,
  timeout: 120_000,
  expect: { timeout: 20_000 },
  outputDir: process.env.E2E_OUT || './resultado',
  reporter: [['list']],
  use: {
    baseURL: process.env.CW_URL || 'http://localhost:3100',
    locale: 'pt-BR',
    viewport: { width: 1440, height: 900 },
    trace: 'on',
    screenshot: 'on',
    video: 'off',
  },
});
