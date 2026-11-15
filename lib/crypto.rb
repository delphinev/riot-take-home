# The one place that picks the algorithms: replacing Base64 or HMAC is a change here only.
module Crypto
  def self.payload_encryptor
    PayloadEncryptor.new(Encryptors::Base64.new)
  end

  def self.payload_signer
    PayloadSigner.new(Signers::Hmac.new(Rails.configuration.x.hmac_secret))
  end
end
