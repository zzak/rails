import { getConfig, sessionStarted, sessionFinished, sessionFailed } from '@web/test-runner-core/browser/session.js';

(async () => {
  console.log('Session starting...');
  sessionStarted();

  const { testFile } = await getConfig();

  console.log('Test file loaded:', testFile);

  let testResults = {
    passed: true,
    suites: [],
  };

  let currentSuite = null;
  let currentTest = null;

  console.log('QUnit tests starting...');

  QUnit.moduleStart(details => {
    console.log('Module started:', details.name);
    currentSuite = {
      name: details.name,
      tests: [],
    };
    testResults.suites.push(currentSuite);
  });

  QUnit.testStart(details => {
    console.log('Test started:', details.name);
    currentTest = {
      name: details.name,
      passed: true,
      skipped: details.skipped,
      assertions: [],
    };
    currentSuite.tests.push(currentTest);
  });

  QUnit.log(details => {
    console.log('Assertion result:', details);
    if (!details.result) {
      currentTest.passed = false;
      testResults.passed = false;
    }
    currentTest.assertions.push({
      message: details.message,
      expected: details.expected,
      actual: details.actual,
      passed: details.result,
      source: details.source,
    });
  });

  QUnit.done(() => {
    console.log('QUnit tests done. Reporting results...');
    sessionFinished({
      passed: testResults.passed,
      testResults,
    });
  });

  try {
    await import(new URL(testFile, document.baseURI).href);
    console.log('Test file executed successfully.');
  } catch (error) {
    console.error('Error loading the test file:', error);
    sessionFailed(error);
  }
})();
