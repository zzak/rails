// test/support/playwright-qunit-test.js
const { test } = require('@playwright/test');
const path = require('path');

test('Run QUnit tests via Playwright', async ({ browser }) => {
  const page = await browser.newPage();

  // Load the QUnit HTML file
  const filePath = `file://${path.resolve(__dirname, 'qunit.html')}`;
  await page.goto(filePath);

  // Wait for the QUnit tests to finish
  const result = await page.evaluate(() => {
    return new Promise((resolve) => {
      const testResults = [];
      QUnit.log((details) => {
        if (!details.result) {
          testResults.push({
            name: details.name,
            message: details.message,
            actual: details.actual,
            expected: details.expected,
            source: details.source,
          });
        }
      });

      QUnit.done((details) => {
        resolve({
          summary: details,
          failedTests: testResults
        });
      });
    });
  });

  // Log the test summary
  console.log('Test result summary:', result.summary);

  // Log detailed information about failed tests
  if (result.failedTests.length > 0) {
    console.log(`\nFailed Tests:\n`);
    result.failedTests.forEach((test, index) => {
      console.log(`Test ${index + 1}:`);
      console.log(`  Name: ${test.name}`);
      console.log(`  Message: ${test.message}`);
      console.log(`  Actual: ${test.actual}`);
      console.log(`  Expected: ${test.expected}`);
      console.log(`  Source: ${test.source}\n`);
    });
  }

  await page.close();

  // Fail the Playwright test if any QUnit tests failed
  if (result.summary.failed > 0) {
    throw new Error(`${result.summary.failed} QUnit test(s) failed`);
  }
});
