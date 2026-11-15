require "rails_helper"

RSpec.describe CanonicalJson do
  describe ".generate" do
    def generate(value) = described_class.generate(value)

    it "gives the same text whatever the order of the keys" do
      expect(generate("message" => "Hello World", "timestamp" => 1_616_161_616))
        .to eq(generate("timestamp" => 1_616_161_616, "message" => "Hello World"))
    end

    it "sorts keys at every depth and writes no whitespace" do
      expect(generate("b" => { "d" => 1, "c" => 2 }, "a" => [ { "f" => 3, "e" => 4 } ]))
        .to eq('{"a":[{"e":4,"f":3}],"b":{"c":2,"d":1}}')
    end

    it "keeps the order of arrays" do
      expect(generate([ 2, 1 ])).not_to eq(generate([ 1, 2 ]))
    end

    it "writes 1.0 as 1, and keeps other floats as they are" do
      expect(generate([ 1.0, 1.5 ])).to eq("[1,1.5]")
    end

    it "writes values that are not objects" do
      expect([ nil, true, "text", 42 ].map { generate(it) }).to eq([ "null", "true", '"text"', "42" ])
    end
  end
end
