// const { chromium } = require('playwright');
const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  //const browser = await chromium.launch({ headless: true });
  const browser = await puppeteer.launch({
    headless: true,
    devtools: true,
  });

  const page = await browser.newPage();

  const filePath = `file://${path.resolve(__dirname, 'qunit.html')}`;
  console.log(`Navigating to: ${filePath}`);
  await page.goto(filePath);

  const result = await page.evaluate(() => {
    return new Promise((resolve) => {
      QUnit.config.testTimeout = 15000;
      const failures = {};

      QUnit.on('runEnd', (details) => {
        failures.details = details;
        /*
        if (details.status === 'failed') {
          const suiteName = details.suiteName;

          if (!failures[suiteName]) {
            failures[suiteName] = [];
          }

          const errors = details.errors
            .filter(error => !error.passed)
            .map(error => error.message);

          if (errors.length > 0) {
            failures[suiteName].push({
              name: details.name,
              errors: errors
            });
          }
        }

        if (details.status === 'failed') {
          const suiteName = details.suiteName;

          // Initialize the suite group if not present
          if (!failedTestsReport[suiteName]) {
            failedTestsReport[suiteName] = [];
          }

          // Collect failed assertions and errors
          const errors = details.errors
            .filter(error => !error.passed)
            .map(error => error.message);

          // If there are errors, add the test to the report
          if (errors.length > 0) {
            failedTestsReport[suiteName].push({
              name: details.name,
              errors: errors
            });
          }
        }
        */
      });

      QUnit.done((details) => {
        resolve({ details: details, failures: failures });
      });
    });
  });

  console.log('Done');
  console.dir(result.details);
  console.dir(result.failures, { depth: null, colors: true });

  /*
  if (Object.keys(result.failures).length === 0) {
    console.log('\nAll tests passed!');
  } else {
    console.log(`\nFailed Tests (${result.failed}):\n`);
    Object.keys(result.failures).forEach((suite) => {
      console.log(`${suite}:`);
      result.failures[suite].forEach(test => {
        console.log(`  ${test.name}`);
        test.errors.forEach(error => {
          console.log(`    ${error}`);
        });
      });
    });
  }
  */

  await browser.close();

  /*
  if (result.failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
  */
})();
