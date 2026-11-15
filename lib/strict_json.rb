# Reads and writes the JSON exchanged with clients. Parsing (request bodies,
# decrypted values) rejects what the json gem accepts but the API could not
# return or sign reliably.
module StrictJson
  class ParseError < StandardError; end

  # The parser already bounds nesting, so the generator's own limit is lifted:
  # whatever was accepted can be written back, even one level deeper in a /decrypt response.
  def self.generate(value)
    JSON.generate(value, max_nesting: false)
  end

  def self.parse(source)
    # The parser accepts invalid UTF-8 silently; it would only fail when the value is written back.
    source = source.dup.force_encoding(Encoding::UTF_8)
    raise ParseError, "is not valid UTF-8" unless source.valid_encoding?

    # Already the default since json 3.0, stated explicitly: signing needs a single value per key.
    value = JSON.parse(source, allow_duplicate_key: false)
    ensure_finite!(value)
    value
  rescue JSON::ParserError
    raise ParseError, "is not valid JSON"
  end

  # Numbers such as 1e400 parse as Infinity, which cannot be written back as JSON.
  def self.ensure_finite!(value)
    case value
    when Float then raise ParseError, "contains a number out of range" unless value.finite?
    when Array then value.each { ensure_finite!(it) }
    when Hash then value.each_value { ensure_finite!(it) }
    end
  end
  private_class_method :ensure_finite!
end
