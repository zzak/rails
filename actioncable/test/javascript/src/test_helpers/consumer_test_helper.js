import { WebSocket as MockWebSocket, Server as MockServer } from "mock-socket";
import * as ActionCable from "../../../../app/javascript/action_cable/index";
import { defer, testURL } from "./index";

export default function(name, options, callback) {
  if (options == null) { options = {}; }
  if (callback == null) {
    callback = options;
    options = {};
  }

  if (options.url == null) { options.url = testURL; }

  describe(name, function() {
    let doneAsync;

    beforeEach(function() {
      doneAsync = new Promise((resolve) => { this.doneAsync = resolve; });

      // Ensure we are mocking WebSocket
      ActionCable.adapters.WebSocket = MockWebSocket;
      this.server = new MockServer(options.url);  // Ensure server URL is mock
      this.consumer = ActionCable.createConsumer(options.url);
      this.connection = this.consumer.connection;
      this.monitor = this.connection.monitor;

      if ("subprotocols" in options) {
        this.consumer.addSubProtocol(options.subprotocols);
      }
    });

    afterEach(function() {
      this.server.close();  // Ensure mock server is closed after each test
    });

    it(name, function(done) {
      const { server, consumer, connection, monitor } = this;

      server.on("connection", function() {
        const clients = server.clients();
        assert.equal(clients.length, 1);
        assert.equal(clients[0].readyState, WebSocket.OPEN);
      });

      server.broadcastTo = function(subscription, data, callback) {
        if (data == null) { data = {}; }
        data.identifier = subscription.identifier;

        if (data.message_type) {
          data.type = ActionCable.INTERNAL.message_types[data.message_type];
          delete data.message_type;
        }

        server.send(JSON.stringify(data));
        defer(callback);
      };

      const doneAsyncLocal = this.doneAsync;

      const finishTest = function() {
        consumer.disconnect();
        server.close();
        doneAsyncLocal.then(done); // Resolve the async and end the test
      };

      const testData = { assert, consumer, connection, monitor, server, done: finishTest };

      if (options.connect === false) {
        callback(testData);
      } else {
        server.on("connection", function() {
          testData.client = server.clients()[0];
          callback(testData);
        });
        consumer.connect();
      }
    });
  });
}
