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
    beforeEach(function() {
      ActionCable.adapters.WebSocket = MockWebSocket;
      this.server = new MockServer(options.url);
      this.consumer = ActionCable.createConsumer(options.url);
      this.connection = this.consumer.connection;
      this.monitor = this.connection.monitor;

      if ("subprotocols" in options) {
        this.consumer.addSubProtocol(options.subprotocols);
      }
    });

    afterEach(function() {
      this.server.close();
    });

    it(name, function(done) {
      const { server, consumer, connection, monitor } = this;
      if (options.timeout != null) { this.timeout(options.timeout); }

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

      const testData = { assert, consumer, connection, monitor, server, done };

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
