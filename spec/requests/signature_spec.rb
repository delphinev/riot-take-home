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

  describe "POST /verify" do
    let(:valid_signature) do
      post_json "/sign", '{"message":"Hello World","timestamp":1616161616}'
      signature
    end

    def verify(signature, data)
      post_json "/verify", { "signature" => signature, "data" => data }.to_json
    end

    it "answers 204 with no body when the signature matches, as in the challenge example", :aggregate_failures do
      verify valid_signature, { "message" => "Hello World", "timestamp" => 1_616_161_616 }

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it "answers 204 whatever the order of the keys, as in the challenge example" do
      verify valid_signature, { "timestamp" => 1_616_161_616, "message" => "Hello World" }

      expect(response).to have_http_status(:no_content)
    end

    it "answers 400 when the data was tampered with, as in the challenge example", :aggregate_failures do
      verify valid_signature, { "timestamp" => 1_616_161_616, "message" => "Goodbye World" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"])
        .to eq("code" => "invalid_signature", "message" => "signature does not match data")
    end

    it "answers 400 when the signature was tampered with", :aggregate_failures do
      verify valid_signature.succ, { "message" => "Hello World", "timestamp" => 1_616_161_616 }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_signature")
    end

    {
      "a missing signature" => '{"data":{"a":1}}',
      "missing data" => '{"signature":"abc"}',
      "a signature that is not a string" => '{"signature":123,"data":{"a":1}}',
      "an extra field" => '{"signature":"abc","data":{"a":1},"timestamp":1}',
      "a body that is not an object" => "[1,2]"
    }.each do |description, body|
      it "rejects #{description} with 400", :aggregate_failures do
        post_json "/verify", body

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]).to eq(
          "code" => "invalid_payload",
          "message" => 'request body must hold exactly a string "signature" and "data"'
        )
      end
    end
  end
end
