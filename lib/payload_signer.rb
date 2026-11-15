# Signs the value of a JSON payload rather than its text: the payload is
# written canonically first, so the order of its keys does not matter.
class PayloadSigner
  # signer: any object responding to #sign(message) and #verify(message, signature),
  # such as Signers::Hmac.
  def initialize(signer)
    @signer = signer
  end

  def sign(data)
    @signer.sign(CanonicalJson.generate(data))
  end

  def verify(data, signature)
    @signer.verify(CanonicalJson.generate(data), signature)
  end
end
