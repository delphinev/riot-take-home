class EncryptionController < ApplicationController
  rescue_from PayloadEncryptor::InvalidPayload do |error|
    render_error :bad_request, "invalid_payload", "request body #{error.message}"
  end

  def encrypt
    render json: Crypto.payload_encryptor.encrypt(json_body)
  end
end
