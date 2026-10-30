import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  timeout: 120_000,
  retries: 0,
  outputDir: process.env.E2E_OUT ? `${process.env.E2E_OUT}/playwright` : 'test-results',
  use: {
    baseURL: process.env.CHATWOOT_URL || 'http://127.0.0.1:3998',
    trace: 'on',
    screenshot: 'on',
    locale: 'pt-BR',
  },
  reporter: [['list'], ['json', { outputFile: `${process.env.E2E_OUT || 'test-results'}/report.json` }]],
});
