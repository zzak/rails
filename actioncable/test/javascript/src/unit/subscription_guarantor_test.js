import * as ActionCable from "../../../../app/javascript/action_cable/index";

describe("ActionCable.SubscriptionGuarantor", function() {
  let guarantor;

  beforeEach(function() {
    guarantor = new ActionCable.SubscriptionGuarantor({});
  });

  describe("#guarantee", function() {
    it("guarantees subscription only once", function() {
      const sub = {};

      assert.equal(guarantor.pendingSubscriptions.length, 0);
      guarantor.guarantee(sub);
      assert.equal(guarantor.pendingSubscriptions.length, 1);
      guarantor.guarantee(sub);
      assert.equal(guarantor.pendingSubscriptions.length, 1);
    });
  });

  describe("#forget", function() {
    it("removes subscription", function() {
      const sub = {};

      assert.equal(guarantor.pendingSubscriptions.length, 0);
      guarantor.guarantee(sub);
      assert.equal(guarantor.pendingSubscriptions.length, 1);
      guarantor.forget(sub);
      assert.equal(guarantor.pendingSubscriptions.length, 0);
    });
  });
});
