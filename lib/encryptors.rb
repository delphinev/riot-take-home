# An encryptor turns a string into a text-safe string and back. Any object
# responding to #algorithm, #encrypt and #decrypt can replace Encryptors::Base64;
# #decrypt raises DecryptionError on input that #encrypt did not produce.
#
# #decrypt returns raw bytes, as a real cipher (e.g. AES-GCM) would:
# checking that they form valid text is the caller's job.
module Encryptors
  class DecryptionError < StandardError; end
end
