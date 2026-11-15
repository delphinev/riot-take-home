# Key used by /sign and /verify. Production must provide it: the app refuses to
# boot rather than sign with a missing or weak key. Development and test fall
# back to a fixed, public key.
hmac_secret = ENV.fetch("HMAC_SECRET") do
  raise "HMAC_SECRET must be set" unless Rails.env.local?

  "insecure-hmac-secret-for-development-and-test"
end

# RFC 2104: a key shorter than the hash output (32 bytes for SHA-256) weakens the HMAC.
raise "HMAC_SECRET must be at least 32 bytes long" if hmac_secret.bytesize < 32

Rails.application.config.x.hmac_secret = hmac_secret
