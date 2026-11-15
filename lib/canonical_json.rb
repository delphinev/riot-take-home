# Writes a JSON value as text that depends only on the value, so that its
# signature does not change with the order of the keys.
module CanonicalJson
  def self.generate(value)
    JSON.generate(normalize(value))
  end

  def self.normalize(value)
    case value
    # Array order is kept: [1, 2] and [2, 1] are different values.
    when Hash then value.sort_by { |key, _| key }.to_h { |key, item| [ key, normalize(item) ] }
    when Array then value.map { normalize(it) }
    # JSON has a single number type: 1.0 and 1 are the same value.
    when Float then value == value.to_i ? value.to_i : value
    else value
    end
  end
  private_class_method :normalize
end
