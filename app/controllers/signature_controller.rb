class SignatureController < ApplicationController
  def sign
    render json: { signature: Crypto.payload_signer.sign(json_body) }
  end
end
