require "rails_helper"

RSpec.describe "Encryption", type: :request do
  def post_json(path, body, content_type: "application/json")
    post path, params: body, headers: { "Content-Type" => content_type }
  end

  def error
    response.parsed_body.fetch("error")
  end

  describe "POST /encrypt" do
    it "encrypts every top-level value, as in the challenge example", :aggregate_failures do
      post_json "/encrypt", <<~JSON
        {
          "name": "John Doe",
          "age": 30,
          "contact": {
            "email": "john@example.com",
            "phone": "123-456-7890"
          }
        }
      JSON

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq(
        "name" => "enc:base64:IkpvaG4gRG9lIg==",
        "age" => "enc:base64:MzA=",
        "contact" => "enc:base64:eyJlbWFpbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJwaG9uZSI6IjEyMy00NTYtNzg5MCJ9"
      )
    end

    it "keeps keys that Rails reserves for routing" do
      post_json "/encrypt", '{"controller":1,"action":2,"format":3}'

      expect(response.parsed_body.keys).to eq([ "controller", "action", "format" ])
    end

    [ "application/json; charset=utf-8", "Application/JSON" ].each do |content_type|
      it "accepts the Content-Type #{content_type.inspect}" do
        post_json "/encrypt", '{"name":"John Doe"}', content_type: content_type

        expect(response).to have_http_status(:ok)
      end
    end

    [ "text/plain", "application/x-www-form-urlencoded" ].each do |content_type|
      it "rejects the Content-Type #{content_type.inspect} with 415", :aggregate_failures do
        post_json "/encrypt", '{"name":"John Doe"}', content_type: content_type

        expect(response).to have_http_status(:unsupported_media_type)
        expect(error).to eq("code" => "unsupported_media_type", "message" => "Content-Type must be application/json")
      end
    end

    it "rejects a request without Content-Type with 415", :aggregate_failures do
      # rack-test always adds a form Content-Type to a POST, so the app is called directly.
      env = Rack::MockRequest.env_for("/encrypt", method: "POST", input: '{"name":"John Doe"}')
      expect(env).not_to have_key("CONTENT_TYPE")

      raw_response = Rack::MockResponse.new(*Rails.application.call(env))

      expect(raw_response.status).to eq(415)
      expect(JSON.parse(raw_response.body).dig("error", "code")).to eq("unsupported_media_type")
    end

    {
      "invalid JSON" => [ '{"name":', "request body is not valid JSON" ],
      "duplicate keys" => [ '{"a":1,"a":2}', "request body is not valid JSON" ],
      "invalid UTF-8" => [ "{\"name\":\"\xFF\"}".b, "request body is not valid UTF-8" ],
      "a number out of range" => [ '{"a":1e400}', "request body contains a number out of range" ]
    }.each do |description, (body, message)|
      it "rejects #{description} with 400", :aggregate_failures do
        post_json "/encrypt", body

        expect(response).to have_http_status(:bad_request)
        expect(error).to eq("code" => "invalid_json", "message" => message)
      end
    end

    [ "[1,2]", '"text"', "null" ].each do |body|
      it "rejects #{body}, which is not an object, with 400", :aggregate_failures do
        post_json "/encrypt", body

        expect(response).to have_http_status(:bad_request)
        expect(error).to eq("code" => "invalid_payload", "message" => "request body must be a JSON object")
      end
    end
  end

  describe "POST /decrypt" do
    let(:encrypted) do
      {
        "name" => "enc:base64:IkpvaG4gRG9lIg==",
        "age" => "enc:base64:MzA=",
        "contact" => "enc:base64:eyJlbWFpbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJwaG9uZSI6IjEyMy00NTYtNzg5MCJ9"
      }
    end

    let(:original) do
      {
        "name" => "John Doe",
        "age" => 30,
        "contact" => { "email" => "john@example.com", "phone" => "123-456-7890" }
      }
    end

    it "restores the original payload, as in the challenge example", :aggregate_failures do
      post_json "/decrypt", encrypted.to_json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(original)
    end

    it "leaves unencrypted values unchanged, as in the challenge example" do
      post_json "/decrypt", encrypted.merge("birth_date" => "1998-11-19").to_json

      expect(response.parsed_body).to eq(original.merge("birth_date" => "1998-11-19"))
    end

    it "rejects a prefixed value that cannot be decrypted with 400", :aggregate_failures do
      post_json "/decrypt", '{"name":"enc:base64:not base64!"}'

      expect(response).to have_http_status(:bad_request)
      expect(error).to eq("code" => "corrupted_value", "message" => 'value of "name" cannot be decrypted')
    end

    it "rejects a body that is not an object with 400", :aggregate_failures do
      post_json "/decrypt", "[1,2]"

      expect(response).to have_http_status(:bad_request)
      expect(error).to eq("code" => "invalid_payload", "message" => "request body must be a JSON object")
    end

    it "requires a JSON Content-Type, like every endpoint" do
      post_json "/decrypt", encrypted.to_json, content_type: "text/plain"

      expect(response).to have_http_status(:unsupported_media_type)
    end
  end
end
