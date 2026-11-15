module Signers
  class Hmac
    def initialize(secret)
      @secret = secret
    end

    def sign(message)
      OpenSSL::HMAC.hexdigest("SHA256", @secret, message)
    end

    # Compared in constant time, so that response times reveal nothing about a forged signature.
    def verify(message, signature)
      OpenSSL.secure_compare(sign(message), signature)
    end
  end
end
