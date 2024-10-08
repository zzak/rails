import consumerTest from "../test_helpers/consumer_test_helper";

describe("ActionCable.Consumer", function() {
  consumerTest("#connect", { connect: false }, function({ consumer, server, assert, done }) {
    server.on("connection", function() {
      assert.equal(consumer.connect(), false);
      done();
    });

    consumer.connect();
  });

  consumerTest("#disconnect", function({ consumer, client, done }) {
    client.addEventListener("close", () => {
      done();
    });
    consumer.disconnect();
  });

  consumerTest("#addSubProtocol", { subprotocols: "some-subprotocol", timeout: 20000 }, function({ consumer, server, assert, done }) {
    server.on("connection", function() {
      assert.equal(consumer.subprotocols.length, 1);
      assert.equal(consumer.subprotocols[0], "some-subprotocol");
      done();
    });

    consumer.connect();
  });
});
