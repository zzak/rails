export const config = {
  // Define Sauce Labs credentials and other WebDriverIO options
  user: process.env.SAUCE_USERNAME,
  key: process.env.SAUCE_ACCESS_KEY,

  specs: [
    'test/javascript/compiled/test.js'
  ],

  capabilities: [{
    browserName: 'chrome',
    platformName: 'Windows 10',
    browserVersion: 'latest',
    'sauce:options': {
      tunnelIdentifier: 'my-tunnel'
    }
  }],

  framework: 'none',  // Since you're using QUnit, you don't need Mocha or Jasmine here

  logLevel: 'info',

  services: ['sauce'],  // Using Sauce Labs service

  sauceConnect: true,  // Enable Sauce Connect if you're tunneling
};

export default config;

