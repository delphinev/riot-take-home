require "rails_helper"

RSpec.describe StrictJson do
  describe ".generate" do
    it "writes values nested deeper than the json gem's default limit of 100" do
      deep = 150.times.reduce(1) { |value, _| [ value ] }

      expect(described_class.generate(deep)).to eq(("[" * 150) + "1" + ("]" * 150))
    end
  end

  describe ".parse" do
    it "parses an object" do
      expect(described_class.parse('{"name":"John Doe","age":30}')).to eq("name" => "John Doe", "age" => 30)
    end

    it "parses a root that is not an object" do
      expect(described_class.parse("[1,2]")).to eq([ 1, 2 ])
      expect(described_class.parse('"text"')).to eq("text")
      expect(described_class.parse("null")).to be_nil
    end

    it "parses Unicode, and escaped Unicode including surrogate pairs" do
      expect(described_class.parse('["é", "\u00e9", "\ud83d\ude00"]')).to eq([ "é", "é", "😀" ])
    end

    it "keeps integers above 2^53 exact" do
      expect(described_class.parse("[9007199254740993]")).to eq([ 9_007_199_254_740_993 ])
    end

    it "parses a binary-encoded body, as Rack provides it" do
      expect(described_class.parse('{"name":"é"}'.b)).to eq("name" => "é")
    end

    {
      "invalid JSON" => "{name: 1}",
      "an empty body" => "",
      "duplicate keys" => '{"a":1,"a":2}',
      "NaN" => "[NaN]",
      "a trailing comma" => "[1,]"
    }.each do |description, source|
      it "rejects #{description}" do
        expect { described_class.parse(source) }.to raise_error(described_class::ParseError, "is not valid JSON")
      end
    end

    it "rejects invalid UTF-8" do
      expect { described_class.parse("{\"name\":\"\xFF\"}".b) }
        .to raise_error(described_class::ParseError, "is not valid UTF-8")
    end

    [ "[1e400]", "[-1e400]", '{"a":{"b":[1e400]}}' ].each do |source|
      it "rejects a number out of range in #{source}" do
        expect { described_class.parse(source) }
          .to raise_error(described_class::ParseError, "contains a number out of range")
      end
    end

    it "does not echo the body in its error message" do
      expect { described_class.parse('{"password":"hunter2",}') }
        .to raise_error(described_class::ParseError) { |error| expect(error.message).not_to include("hunter2") }
    end
  end
end
