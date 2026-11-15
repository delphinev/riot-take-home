class EncryptionController < ApplicationController
  rescue_from PayloadEncryptor::InvalidPayload do |error|
    render_error :bad_request, "invalid_payload", "request body #{error.message}"
  end

  rescue_from PayloadEncryptor::CorruptedValue do |error|
    render_error :bad_request, "corrupted_value", error.message
  end

  def encrypt
    render json: Crypto.payload_encryptor.encrypt(json_body)
  end

  def decrypt
    render json: Crypto.payload_encryptor.decrypt(json_body)
  end
end
