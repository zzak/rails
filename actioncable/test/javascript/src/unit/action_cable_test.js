import * as ActionCable from "../../../../app/javascript/action_cable/index";
import { testURL } from "../test_helpers/index";

describe("ActionCable", () => {
  describe("Adapters", () => {
    describe("WebSocket", () => {
      it("default is WebSocket", () => {
        assert.strictEqual(ActionCable.adapters.WebSocket, self.WebSocket);
      });
    });

    describe("logger", () => {
      it("default is console", () => {
        assert.strictEqual(ActionCable.adapters.logger, self.console);
      });
    });
  });

  describe("#createConsumer", () => {
    it("uses specified URL", () => {
      const consumer = ActionCable.createConsumer(testURL);
      assert.strictEqual(consumer.url, testURL);
    });

    it("uses default URL", () => {
      const pattern = new RegExp(`${ActionCable.INTERNAL.default_mount_path}$`);
      const consumer = ActionCable.createConsumer();
      assert.ok(pattern.test(consumer.url), `Expected ${consumer.url} to match ${pattern}`);
    });

    it("uses URL from meta tag", () => {
      const element = document.createElement("meta");
      element.setAttribute("name", "action-cable-url");
      element.setAttribute("content", testURL);

      document.head.appendChild(element);
      const consumer = ActionCable.createConsumer();
      document.head.removeChild(element);

      assert.strictEqual(consumer.url, testURL);
    });

    it("dynamically computes URL from function", () => {
      let dynamicURL = testURL;
      const generateURL = () => dynamicURL;
      const consumer = ActionCable.createConsumer(generateURL);
      assert.strictEqual(consumer.url, testURL);

      dynamicURL = `${testURL}foo`;
      assert.strictEqual(consumer.url, `${testURL}foo`);
    });
  });
});
