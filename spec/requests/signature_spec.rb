require "rails_helper"

RSpec.describe "Signature", type: :request do
  def post_json(path, body, content_type: "application/json")
    post path, params: body, headers: { "Content-Type" => content_type }
  end

  def signature
    response.parsed_body.fetch("signature")
  end

  describe "POST /sign" do
    it "returns an HMAC-SHA256 signature as lowercase hex", :aggregate_failures do
      post_json "/sign", '{"message":"Hello World","timestamp":1616161616}'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to eq([ "signature" ])
      expect(signature).to match(/\A\h{64}\z/).and eq(signature.downcase)
    end

    it "gives the same signature whatever the order of the keys, as in the challenge example" do
      post_json "/sign", '{"message":"Hello World","timestamp":1616161616}'
      first = signature
      post_json "/sign", '{"timestamp":1616161616,"message":"Hello World"}'

      expect(signature).to eq(first)
    end

    it "gives a different signature for different data" do
      post_json "/sign", '{"message":"Hello World"}'
      first = signature
      post_json "/sign", '{"message":"Goodbye World"}'

      expect(signature).not_to eq(first)
    end

    [ "[1,2]", '"text"', "null" ].each do |body|
      it "signs #{body}, since any JSON value can be signed", :aggregate_failures do
        post_json "/sign", body

        expect(response).to have_http_status(:ok)
        expect(signature).to match(/\A\h{64}\z/)
      end
    end

    it "rejects invalid JSON with 400, like every endpoint", :aggregate_failures do
      post_json "/sign", '{"message":'

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_json")
    end

    it "requires a JSON Content-Type, like every endpoint" do
      post_json "/sign", '{"message":"Hello World"}', content_type: "text/plain"

      expect(response).to have_http_status(:unsupported_media_type)
    end
  end
end
