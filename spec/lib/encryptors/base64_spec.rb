require "rails_helper"

RSpec.describe Encryptors::Base64 do
  subject(:encryptor) { described_class.new }

  it "names its algorithm" do
    expect(encryptor.algorithm).to eq("base64")
  end

  it "encrypts with standard Base64" do
    expect(encryptor.encrypt('"John Doe"')).to eq("IkpvaG4gRG9lIg==")
  end

  [ "John Doe", "é😀", "" ].each do |plaintext|
    it "decrypts what it encrypts: #{plaintext.inspect}" do
      expect(encryptor.decrypt(encryptor.encrypt(plaintext)).bytes).to eq(plaintext.bytes)
    end
  end

  it "never adds line breaks, even to long inputs" do
    expect(encryptor.encrypt("a" * 100)).not_to include("\n")
  end

  {
    "an invalid character" => "Ikpv*G4=",
    "missing padding" => "abc",
    "a line break" => "IkpvaG4g\nRG9lIg=="
  }.each do |description, ciphertext|
    it "refuses to decrypt #{description}" do
      expect { encryptor.decrypt(ciphertext) }
        .to raise_error(Encryptors::DecryptionError, "invalid Base64")
    end
  end
end
