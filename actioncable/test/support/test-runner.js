const { chromium } = require('playwright');
const path = require('path');

(async () => {
  let browser = await chromium.launch({ headless: true });

  const page = await browser.newPage();
  const filepath = `file://${path.resolve(__dirname, 'qunit.html')}`;
  console.log(`navigating to: ${filepath}`);
  await page.goto(filepath);

  const result = await page.evaluate(() => {
    return new Promise((resolve) => {
      QUnit.config.testTimeout = 15000;
      const failures = {};
      const exceptions = [];

      QUnit.on('error', error => {
        exceptions.push(error);
      });

      QUnit.log((details) => {
        if (!details.result) {
          if (!failures[details.module]) {
            failures[details.module] = [];
          }

          failures[details.module].push({
            testName: details.name,
            message: details.message,
            expected: details.expected,
            actual: details.actual,
          });
        }
      });

      QUnit.done((details) => {
        resolve({ details: details, exceptions: exceptions, failures: failures });
      });

      QUnit.start();
    });
  });

  if (result.exceptions.length > 0) {
    console.log('\nExceptions:\n');
    result.exceptions.forEach(exception => {
      console.log(exception);
    });
    process.exit(1);
  }

  if (result.details.failed > 0) {
    console.log(`\nFailed Tests:\n`);
    Object.keys(result.failures).forEach(moduleName => {
      console.log(`${moduleName}:`);
      result.failures[moduleName].forEach(failure => {
        console.log(`  Test: ${failure.testName}`);
        console.log(`    Expected: ${failure.expected}`);
        console.log(`    Got: ${failure.actual}`);
        if (failure.message !== undefined) {
          console.log(`    ${failure.message}`);
        }
        console.log('');
      });
    });
  } else {
    console.log('\nAll tests passed!');
  }

  console.log(`Test Results Summary: ${result.details.passed} passed, ${result.details.failed} failed, ${result.details.total} total, ${result.details.runtime}ms runtime`);

  await browser.close();

  if (result.details.failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
})();
