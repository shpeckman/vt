# spec/parser_spec.cr
require "./spec_helper"

describe VT::Parser do
  corpus_file = File.join(__DIR__, "corpus", "parser.yml")
  test_cases  = YAML.parse(File.read(corpus_file)).as_a

  test_cases.each do |tc|
    it tc["name"].as_s do
      spy    = SpyHandler.new
      parser = VT::Parser.new(spy)

      # Parse string as raw codepoints to correctly feed 8-bit characters (like C1 controls)
      codepoints = tc["input"].as_s.codepoints
      bytes      = Bytes.new(codepoints.size) { |i| codepoints[i].to_u8 }

      parser.parse(bytes)

      spy.events.to_json.should eq(tc["expected"].to_json)
    end
  end

  it "reports idle status accurately" do
    spy    = SpyHandler.new
    parser = VT::Parser.new(spy)

    parser.idle?.should be_true
    parser.parse("\e")
    parser.idle?.should be_false
    parser.parse("c")
    parser.idle?.should be_true
  end

  it "resets state" do
    spy    = SpyHandler.new
    parser = VT::Parser.new(spy)

    parser.parse("\e[")
    parser.idle?.should be_false

    parser.reset
    parser.idle?.should be_true
  end
end
