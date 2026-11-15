require "rails_helper"

RSpec.describe "Deeply nested payloads", type: :request do
  def post_json(path, body)
    post path, params: body, headers: { "Content-Type" => "application/json" }
  end

  # The deepest body StrictJson still accepts, whatever the json gem's limit (about 100 levels).
  def deepest(&build)
    depth = 1
    depth += 1 while accepted?(build.call(depth + 1))
    build.call(depth)
  end

  def accepted?(source)
    StrictJson.parse(source)
    true
  rescue StrictJson::ParseError
    false
  end

  def nested_arrays(depth)
    ("[" * depth) + ("]" * depth)
  end

  let(:deepest_array) { deepest { |depth| nested_arrays(depth) } }
  let(:deepest_object) { deepest { |depth| %({"a":#{nested_arrays(depth)}}) } }

  it "signs the deepest data the parser accepts" do
    post_json "/sign", deepest_array

    expect(response).to have_http_status(:ok)
  end

  it "decrypts what /encrypt returned for the deepest payload the parser accepts", :aggregate_failures do
    post_json "/encrypt", deepest_object
    expect(response).to have_http_status(:ok)
    post_json "/decrypt", response.body

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq(deepest_object)
  end

  it "returns the deepest unencrypted payload the parser accepts unchanged", :aggregate_failures do
    post_json "/decrypt", deepest_object

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq(deepest_object)
  end

  it "rejects one level more with 400", :aggregate_failures do
    post_json "/sign", "[#{deepest_array}]"

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_json")
  end
end
