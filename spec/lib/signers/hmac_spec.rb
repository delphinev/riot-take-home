require "rails_helper"

RSpec.describe Signers::Hmac do
  subject(:signer) { described_class.new("secret") }

  describe "#sign" do
    # Key, message and expected signature are the official HMAC-SHA256 example
    # published in RFC 4231 (test case 2).
    it "matches the official HMAC-SHA256 example, as lowercase hex" do
      expect(described_class.new("Jefe").sign("what do ya want for nothing?"))
        .to eq("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
    end

    it "gives a different signature for a different message or secret", :aggregate_failures do
      expect(signer.sign("message")).not_to eq(signer.sign("other message"))
      expect(signer.sign("message")).not_to eq(described_class.new("other secret").sign("message"))
    end
  end

  describe "#verify" do
    it "accepts the signature of the message" do
      expect(signer.verify("message", signer.sign("message"))).to be(true)
    end

    it "rejects the signature of another message" do
      expect(signer.verify("tampered message", signer.sign("message"))).to be(false)
    end

    it "rejects a tampered or truncated signature", :aggregate_failures do
      signature = signer.sign("message")

      expect(signer.verify("message", signature.succ)).to be(false)
      expect(signer.verify("message", signature[0..-2])).to be(false)
      expect(signer.verify("message", "")).to be(false)
    end

    it "rejects a signature made with another secret" do
      expect(signer.verify("message", described_class.new("other secret").sign("message"))).to be(false)
    end
  end
end
