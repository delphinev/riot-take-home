require "rails_helper"

RSpec.describe "Parameter filtering" do
  subject(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "filters every value, whatever its key" do
    expect(filter.filter("name" => "John", "contact" => { "email" => "john@example.com" }))
      .to eq("name" => "[FILTERED]", "contact" => "[FILTERED]")
  end

  it "filters an empty key" do
    expect(filter.filter("" => "secret")).to eq("" => "[FILTERED]")
  end

  it "filters a body whose root is not an object" do
    expect(filter.filter("_json" => [ 1, 2 ])).to eq("_json" => "[FILTERED]")
  end
end
