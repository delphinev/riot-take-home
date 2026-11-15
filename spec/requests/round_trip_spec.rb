require "rails_helper"

RSpec.describe "Round trips", type: :request do
  def post_json(path, body)
    post path, params: body, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:ok)
    response.body
  end

  describe "POST /encrypt, then POST /decrypt" do
    {
      "every JSON type" => {
        "string" => "John Doe", "integer" => 30, "float" => 1.5, "true" => true, "false" => false,
        "null" => nil, "array" => [ 1, "two", [ 3 ] ], "object" => { "a" => { "b" => 1 } }
      },
      "empty values" => { "string" => "", "array" => [], "object" => {} },
      "an empty object" => {},
      "numbers that differ only in type" => { "integer" => 1, "float" => 1.0, "negative zero" => -0.0 },
      "integers beyond 2^53" => { "big" => 9_007_199_254_740_993, "negative" => -9_007_199_254_740_993 },
      "decimals" => { "small" => 1.0e-7, "large" => 1.5e300, "inexact" => 0.1 },
      "Unicode and escapes" => {
        "accents" => "é", "emoji" => "😀", "CJK" => "日本",
        "escapes" => "quote \" backslash \\ newline \n tab \t", "control" => "a#{0.chr}b",
        "line separator" => "a#{0x2028.chr(Encoding::UTF_8)}b", "html" => "<script>&</script>"
      },
      "strings that look encrypted" => { "prefixed" => "enc:base64:IkpvaG4gRG9lIg==", "base64" => "MTIz" },
      "keys Rails reserves" => { "controller" => 1, "action" => 2, "format" => 3, "_json" => 4 },
      "unusual keys" => { "" => "empty", "é" => "accent", "a.b" => "dot", "a[b]" => "brackets" }
    }.each do |description, payload|
      it "restores #{description} exactly", :aggregate_failures do
        encrypted = post_json("/encrypt", payload.to_json)
        decrypted = post_json("/decrypt", encrypted)

        # Compared as normalized JSON text, so that a type change (1 into 1.0) would fail too.
        expect(JSON.generate(JSON.parse(decrypted))).to eq(JSON.generate(payload))
      end
    end
  end
end
