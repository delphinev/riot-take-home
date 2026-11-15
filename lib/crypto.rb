# The one place that picks the algorithm: replacing Base64 is a change here only.
module Crypto
  def self.payload_encryptor
    PayloadEncryptor.new(Encryptors::Base64.new)
  end
end
