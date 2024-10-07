import { defineConfig } from '@playwright/test';
import path from 'path';

export default defineConfig({
  // No need for testDir since you aren't discovering tests automatically
  timeout: 60000,

  retries: process.env.CI ? 2 : 0,

  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report' }]
  ],

  projects: [
    {
      name: 'Chromium Headless',
      use: { browserName: 'chromium', headless: true }
    },
    {
      name: 'Chromium Headed',
      use: { browserName: 'chromium', headless: false }
    }
  ],

  use: {
    baseURL: `file://${path.resolve(__dirname, 'test/support/qunit.html')}`,  // Point to qunit.html
    screenshot: 'on',
    video: 'retain-on-failure',
  }
});
