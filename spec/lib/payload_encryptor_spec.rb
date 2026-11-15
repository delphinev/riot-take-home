require "rails_helper"

RSpec.describe PayloadEncryptor do
  subject(:payload_encryptor) { described_class.new(Encryptors::Base64.new) }

  let(:payload) do
    {
      "name" => "John Doe",
      "age" => 30,
      "contact" => { "email" => "john@example.com", "phone" => "123-456-7890" }
    }
  end

  def encrypted_value(plaintext)
    "enc:base64:#{Base64.strict_encode64(plaintext)}"
  end

  describe "#encrypt" do
    it "encrypts every top-level value, nested objects as a single value" do
      expect(payload_encryptor.encrypt(payload)).to eq(
        "name" => "enc:base64:IkpvaG4gRG9lIg==",
        "age" => "enc:base64:MzA=",
        "contact" => "enc:base64:eyJlbWFpbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJwaG9uZSI6IjEyMy00NTYtNzg5MCJ9"
      )
    end

    it "encrypts values of every JSON type" do
      encrypted = payload_encryptor.encrypt("a" => true, "b" => nil, "c" => [ 1, "x" ], "d" => 1.5, "e" => "")

      expect(encrypted.values).to all(start_with("enc:base64:"))
    end

    it "keeps the keys and their order" do
      expect(payload_encryptor.encrypt("b" => 1, "a" => 2, "" => 3).keys).to eq([ "b", "a", "" ])
    end

    it "returns an empty object unchanged" do
      expect(payload_encryptor.encrypt({})).to eq({})
    end

    it "encrypts a value that already looks encrypted" do
      encrypted = payload_encryptor.encrypt("name" => "enc:base64:IkpvaG4gRG9lIg==")

      expect(payload_encryptor.decrypt(encrypted)).to eq("name" => "enc:base64:IkpvaG4gRG9lIg==")
    end

    [ [ 1, 2 ], "text", nil ].each do |payload|
      it "rejects #{payload.inspect}, which is not an object" do
        expect { payload_encryptor.encrypt(payload) }
          .to raise_error(described_class::InvalidPayload, "must be a JSON object")
      end
    end
  end

  describe "#decrypt" do
    it "restores the original payload, with the type of every value" do
      expect(payload_encryptor.decrypt(payload_encryptor.encrypt(payload))).to eq(payload)
    end

    it "leaves unencrypted values unchanged" do
      unencrypted = { "birth_date" => "1998-11-19", "code" => "MTIz", "age" => 30, "contact" => { "a" => 1 } }

      expect(payload_encryptor.decrypt(unencrypted)).to eq(unencrypted)
    end

    it "decrypts encrypted values next to unencrypted ones" do
      mixed = payload_encryptor.encrypt("name" => "John Doe").merge("birth_date" => "1998-11-19")

      expect(payload_encryptor.decrypt(mixed)).to eq("name" => "John Doe", "birth_date" => "1998-11-19")
    end

    it "does not decrypt nested values, since only top-level values are encrypted" do
      nested = { "contact" => { "email" => encrypted_value('"john@example.com"') } }

      expect(payload_encryptor.decrypt(nested)).to eq(nested)
    end

    it "leaves a value encrypted with another algorithm unchanged" do
      expect(payload_encryptor.decrypt("name" => "enc:aes:abc")).to eq("name" => "enc:aes:abc")
    end

    {
      "invalid Base64" => "enc:base64:not base64!",
      "an empty ciphertext" => "enc:base64:",
      "a ciphertext that is not JSON" => "enc:base64:#{Base64.strict_encode64('John Doe')}",
      "a number out of range" => "enc:base64:#{Base64.strict_encode64('1e400')}",
      "invalid UTF-8" => "enc:base64:#{Base64.strict_encode64("\"\xFF\"".b)}"
    }.each do |description, value|
      it "rejects a prefixed value holding #{description}" do
        expect { payload_encryptor.decrypt("name" => value) }
          .to raise_error(described_class::CorruptedValue, 'value of "name" cannot be decrypted')
      end
    end

    [ [ 1, 2 ], "text", nil ].each do |payload|
      it "rejects #{payload.inspect}, which is not an object" do
        expect { payload_encryptor.decrypt(payload) }
          .to raise_error(described_class::InvalidPayload, "must be a JSON object")
      end
    end
  end

  context "with another encryptor" do
    subject(:payload_encryptor) { described_class.new(reversing_encryptor) }

    let(:reversing_encryptor) do
      Class.new do
        def algorithm = "reverse"
        def encrypt(plaintext) = plaintext.reverse
        def decrypt(ciphertext) = ciphertext.reverse
      end.new
    end

    it "names that algorithm in the prefix" do
      expect(payload_encryptor.encrypt("name" => "John Doe")).to eq("name" => 'enc:reverse:"eoD nhoJ"')
    end

    it "restores the original payload without any other change" do
      expect(payload_encryptor.decrypt(payload_encryptor.encrypt(payload))).to eq(payload)
    end
  end
end
