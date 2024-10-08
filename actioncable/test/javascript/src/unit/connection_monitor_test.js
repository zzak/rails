import * as ActionCable from "../../../../app/javascript/action_cable/index";

describe("ActionCable.ConnectionMonitor", function() {
  let monitor;

  beforeEach(function() {
    monitor = new ActionCable.ConnectionMonitor({});
  });

  describe("#getPollInterval", function() {
    const { staleThreshold, reconnectionBackoffRate } = ActionCable.ConnectionMonitor;
    const backoffFactor = 1 + reconnectionBackoffRate;
    const ms = 1000;

    beforeEach(function() {
      this._originalMathRandom = Math.random;
    });

    afterEach(function() {
      Math.random = this._originalMathRandom;
    });

    it("uses exponential backoff", function() {
      Math.random = () => 0;

      monitor.reconnectAttempts = 0;
      assert.equal(monitor.getPollInterval(), staleThreshold * ms);

      monitor.reconnectAttempts = 1;
      assert.equal(monitor.getPollInterval(), staleThreshold * backoffFactor * ms);

      monitor.reconnectAttempts = 2;
      assert.equal(monitor.getPollInterval(), staleThreshold * backoffFactor * backoffFactor * ms);
    });

    it("caps exponential backoff after some number of reconnection attempts", function() {
      Math.random = () => 0;
      monitor.reconnectAttempts = 42;
      const cappedPollInterval = monitor.getPollInterval();

      monitor.reconnectAttempts = 9001;
      assert.equal(monitor.getPollInterval(), cappedPollInterval);
    });

    it("uses 100% jitter when 0 reconnection attempts", function() {
      Math.random = () => 0;
      assert.equal(monitor.getPollInterval(), staleThreshold * ms);

      Math.random = () => 0.5;
      assert.equal(monitor.getPollInterval(), staleThreshold * 1.5 * ms);
    });

    it("uses reconnectionBackoffRate for jitter when >0 reconnection attempts", function() {
      monitor.reconnectAttempts = 1;

      Math.random = () => 0.25;
      assert.equal(
        monitor.getPollInterval(),
        staleThreshold * backoffFactor * (1 + reconnectionBackoffRate * 0.25) * ms
      );

      Math.random = () => 0.5;
      assert.equal(
        monitor.getPollInterval(),
        staleThreshold * backoffFactor * (1 + reconnectionBackoffRate * 0.5) * ms
      );
    });

    it("applies jitter after capped exponential backoff", function() {
      monitor.reconnectAttempts = 9001;

      Math.random = () => 0;
      const withoutJitter = monitor.getPollInterval();

      Math.random = () => 0.5;
      const withJitter = monitor.getPollInterval();

      assert.isAbove(withJitter, withoutJitter);
    });
  });
});
