//import { createSauceLabsLauncher } from '@web/test-runner-saucelabs';
import { chromeLauncher } from '@web/test-runner-chrome';

export default {
  browsers: [
    chromeLauncher({ launchOptions: { headless: false, devtools: true } }),
    /*
    createSauceLabsLauncher({
      user: process.env.SAUCE_USERNAME,
      key: process.env.SAUCE_ACCESS_KEY,
      browserName: 'chrome',
      platformName: 'Windows 10',
      browserVersion: 'latest',
      sauceOptions: {
        name: 'My Test',
        build: 'Build 1',
      },
    }),
    */
  ],
  files: ['./test/support/qunit2.html'],
  //files: ['test/javascript/compiled/test.js'],
  testFramework: {
    path: './test/support/wtr-qunit.js',
  },
  //testStartTimeout: 60000,
};
