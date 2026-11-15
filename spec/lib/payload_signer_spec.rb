require "rails_helper"

RSpec.describe PayloadSigner do
  subject(:payload_signer) { described_class.new(Signers::Hmac.new("secret")) }

  let(:data) { { "message" => "Hello World", "timestamp" => 1_616_161_616 } }

  describe "#sign" do
    it "gives the same signature whatever the order of the keys, as in the challenge example" do
      expect(payload_signer.sign("message" => "Hello World", "timestamp" => 1_616_161_616))
        .to eq(payload_signer.sign("timestamp" => 1_616_161_616, "message" => "Hello World"))
    end

    it "signs any JSON value" do
      expect([ [ 1, 2 ], "text", nil ].map { payload_signer.sign(it) }.uniq.size).to eq(3)
    end

    it "gives different signatures to values that only look alike", :aggregate_failures do
      expect(payload_signer.sign("a" => "1")).not_to eq(payload_signer.sign("a" => 1))
      expect(payload_signer.sign("a" => nil)).not_to eq(payload_signer.sign({}))
      expect(payload_signer.sign([ 1, 2 ])).not_to eq(payload_signer.sign([ 2, 1 ]))
    end
  end

  describe "#verify" do
    it "accepts the signature of the data, whatever the order of its keys" do
      expect(payload_signer.verify(data.to_a.reverse.to_h, payload_signer.sign(data))).to be(true)
    end

    it "rejects tampered data, as in the challenge example" do
      tampered = data.merge("message" => "Goodbye World")

      expect(payload_signer.verify(tampered, payload_signer.sign(data))).to be(false)
    end

    it "rejects a tampered signature" do
      expect(payload_signer.verify(data, payload_signer.sign(data).succ)).to be(false)
    end
  end

  context "with another signer" do
    subject(:payload_signer) { described_class.new(echo_signer) }

    let(:echo_signer) do
      Class.new do
        def sign(message) = message
        def verify(message, signature) = message == signature
      end.new
    end

    it "hands it the canonical form of the data" do
      expect(payload_signer.sign("timestamp" => 1_616_161_616, "message" => "Hello World"))
        .to eq('{"message":"Hello World","timestamp":1616161616}')
    end

    it "verifies through it" do
      expect(payload_signer.verify(data, payload_signer.sign(data))).to be(true)
    end
  end
end
