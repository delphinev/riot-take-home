class SignatureController < ApplicationController
  def sign
    render_json({ signature: Crypto.payload_signer.sign(json_body) })
  end

  def verify
    unless verification_request?(json_body)
      return render_error :bad_request, "invalid_payload", 'request body must hold exactly a string "signature" and "data"'
    end

    if Crypto.payload_signer.verify(json_body["data"], json_body["signature"])
      head :no_content
    else
      render_error :bad_request, "invalid_signature", "signature does not match data"
    end
  end

  private

  # Exactly these two fields: any other one would look signed while it is not.
  def verification_request?(body)
    body.is_a?(Hash) && body.keys.sort == %w[data signature] && body["signature"].is_a?(String)
  end
end
