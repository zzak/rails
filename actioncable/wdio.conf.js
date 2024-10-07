const path = require('path');

exports.config = {
  // Sauce Labs credentials
  user: process.env.SAUCE_USERNAME,
  key: process.env.SAUCE_ACCESS_KEY,

  // Sauce Labs region and options
  // sauceRegion: 'us-west-1',

  specs: [
    //path.resolve(__dirname, 'test/support/qunit.html')
    //'test/support/qunit.html'
    'test/javascript/compiled/test.js'
  ],

  capabilities: [
    {
      browserName: 'chrome',
      platformName: 'Windows 10',
      browserVersion: 'latest',
      'sauce:options': {
        tunnelIdentifier: 'my-tunnel'
      }
    },
    {
      browserName: 'firefox',
      platformName: 'macOS 12',
      browserVersion: 'latest',
      'sauce:options': {
        tunnelIdentifier: 'my-tunnel'
      }
    }
  ],

  // Specify Sauce Connect if using it
  services: ['sauce'],
  sauceConnect: true, // Set to false if you don't need Sauce Connect

  framework: 'none', // Not using Mocha/Jasmine

  // Hooks for test status reporting
  afterTest: function(test, context, { error, result, duration, passed }) {
    if (!passed) {
      console.log(`Test failed: ${test.title}`);
    }
  }
};

