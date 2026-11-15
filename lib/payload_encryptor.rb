# Encrypts every top-level value of a JSON object, and decrypts the values it
# encrypted while leaving every other value unchanged.
class PayloadEncryptor
  class InvalidPayload < StandardError; end
  class CorruptedValue < StandardError; end

  def initialize(encryptor)
    @encryptor = encryptor
    # Many plain strings are valid Base64, so only prefixed values are decrypted.
    # The prefix names the algorithm: a value encrypted by another one is never misread.
    @prefix = "enc:#{encryptor.algorithm}:"
  end

  def encrypt(payload)
    ensure_object!(payload)

    # Values are serialized first, so that their type (30, true, nested objects) survives the round trip.
    payload.transform_values { |value| @prefix + @encryptor.encrypt(StrictJson.generate(value)) }
  end

  def decrypt(payload)
    ensure_object!(payload)

    payload.to_h { |key, value| [ key, encrypted?(value) ? decrypt_value(key, value) : value ] }
  end

  private

  def ensure_object!(payload)
    raise InvalidPayload, "must be a JSON object" unless payload.is_a?(Hash)
  end

  def encrypted?(value)
    value.is_a?(String) && value.start_with?(@prefix)
  end

  def decrypt_value(key, value)
    StrictJson.parse(@encryptor.decrypt(value.delete_prefix(@prefix)))
  rescue Encryptors::DecryptionError, StrictJson::ParseError
    raise CorruptedValue, "value of #{key.inspect} cannot be decrypted"
  end
end
