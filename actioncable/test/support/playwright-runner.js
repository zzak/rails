const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  const filePath = `file://${path.resolve(__dirname, 'qunit.html')}`;
  console.log(`Navigating to: ${filePath}`);
  await page.goto(filePath);

  // Capture console logs from the page
  page.on('console', (msg) => {
    console.log(`PAGE LOG: ${msg.text()}`);
  });

  /*
  // Evaluate QUnit events and capture test results
  const result = await page.evaluate(() => {
    return new Promise((resolve) => {
      const failedTests = [];

      console.log('Setting up QUnit hooks');
      QUnit.config.testTimeout = 10000;

      QUnit.testDone((testDetails) => {
        console.log(`QUnit.testDone for test "${testDetails.name}" with ${testDetails.failed} failures`);
        if (testDetails.failed > 0) {
          const failedAssertions = testDetails.assertions
            .filter((assertion) => !assertion.result)
            .map((assertion) => ({
              message: assertion.message || 'No message',
              actual: JSON.stringify(assertion.actual) || 'No actual',
              expected: JSON.stringify(assertion.expected) || 'No expected',
              source: assertion.source || 'No source',
            }));

          console.log('Captured failed assertions:', failedAssertions);

          failedTests.push({
            testName: testDetails.name,
            module: testDetails.module || 'No module',
            failedAssertions,
          });
        }
      });

      QUnit.done((details) => {
        console.log('QUnit tests finished.');
        resolve({
          passed: details.passed,
          failed: details.failed,
          total: details.total,
          runtime: details.runtime,
          failedTests,
        });
      });
    });
    */
  const result = await page.evaluate(() => {
    return new Promise((resolve) => {
      QUnit.config.testTimeout = 15000;
      const failures = {};

      QUnit.on('testEnd', (details) => {
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
      });

      QUnit.done(() => {
        resolve({ failures: failures });
      });

      /*
      const logs = [];
      const done = [];
      const end = [];
      const exceptions = [];

      /*
      const testResults = [];
      QUnit.log((details) => {
        testResults.push({
          name: details.name,
          module: details.module,
          message: details.message,
          actual: details.actual,
          expected: details.expected,
          result: details.result,
          source: details.source,
        });
      });
      */

      /*
      QUnit.onUncaughtException((exception) => {
        exceptions.push(exception);
      });

      QUnit.log((details) => {
        if (!details.result) {
          logs.push(details);
        }
        //logs.push(details);
      });

      QUnit.testDone((details) => {
        done.push(details);
      });

      QUnit.on('testEnd', (details) => {
        end.push(details);
      });

      QUnit.on('testEnd', (details) => {
        const failedTestsReport = {};

        // Only process failed tests
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
      });

      QUnit.done((details) => {
        resolve({
          summary: details,
          logs: logs,
          done: done,
          end: end,
          exceptions: exceptions,
          //results: testResults
        });
      });

      */
    });
  });

  // Log the final test result summary in Node
  console.log('Done');

  //console.dir(result, { depth: null, colors: true });
  //
  //

  /*
  // Log detailed information about each failed test
  if (result.results.length > 0) {
    console.log(`\nTests (${result.results.length}):\n`);
    result.results.forEach((test, index) => {
      console.log(`Test ${index + 1}:`);
      console.log(`  Test Name: ${test.testName}`);
      console.log(`  Module: ${test.module}`);
      console.log(`  Result: ${test.result}`);
      if (typeof test.failedAssertions !== 'undefined' && test.failedAssertions.length > 0) {
        test.failedAssertions.forEach((assertion, i) => {
          console.log(`    Assertion ${i + 1}:`);
          console.log(`      Message: ${assertion.message}`);
          console.log(`      Actual: ${assertion.actual}`);
          console.log(`      Expected: ${assertion.expected}`);
          console.log(`      Source: ${assertion.source}`);
        });
      }
    });
  }
  */

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

  await browser.close();

  if (result.failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
})();

/*
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  const filePath = `file://${path.resolve(__dirname, 'qunit.html')}`;
  await page.goto(filePath);

  const failedTests = [];

  const result = await page.evaluate(() => {
    return new Promise((resolve) => {

      //QUnit.config.testTimeout = 5000;

      QUnit.testDone((testDetails) => {
        if (testDetails.failed > 0) {
          const failedAssertions = testDetails.assertions
            .filter((assertion) => !assertion.result)
            .map((assertion) => ({
              message: assertion.message || 'No message',
              actual: JSON.stringify(assertion.actual) || 'No actual',
              expected: JSON.stringify(assertion.expected) || 'No expected',
              source: assertion.source || 'No source',
            }));

          failedTests.push({
            testName: testDetails.name,
            module: testDetails.module || 'No module',
            failedAssertions,
          });
        }
      });

      QUnit.done((details) => {
        resolve({
          passed: details.passed,
          failed: details.failed,
          total: details.total,
          runtime: details.runtime,
          failedTests,
        });
      });
    });
  });

  console.log('Final Test result summary:', result);

  if (result.failedTests.length > 0) {
    console.log(`\nFailed Tests (${result.failedTests.length}):\n`);
    result.failedTests.forEach((test, index) => {
      console.log(`Test ${index + 1}:`);
      console.log(`  Test Name: ${test.testName}`);
      console.log(`  Module: ${test.module}`);
      test.failedAssertions.forEach((assertion, i) => {
        console.log(`    Assertion ${i + 1}:`);
        console.log(`      Message: ${assertion.message}`);
        console.log(`      Actual: ${assertion.actual}`);
        console.log(`      Expected: ${assertion.expected}`);
        console.log(`      Source: ${assertion.source}`);
      });
    });
  } else {
    console.log('\nAll tests passed!');
  }

  await browser.close();

  if (result.failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
})();
*/
