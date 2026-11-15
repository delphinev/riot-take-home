module Encryptors
  class Base64
    def algorithm
      "base64"
    end

    def encrypt(plaintext)
      ::Base64.strict_encode64(plaintext)
    end

    def decrypt(ciphertext)
      ::Base64.strict_decode64(ciphertext)
    rescue ArgumentError
      raise DecryptionError, "invalid Base64"
    end
  end
end
