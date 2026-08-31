# spec/buffered_handler_spec.cr
require "./spec_helper"

describe VT::BufferedHandler do
  it "decodes UTF-8 into prints" do
    spy    = BufferedSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("A\xE2\x82\xACC")
    spy.events.to_json.should eq(JSON.parse(%([["print", "A"], ["print", "€"], ["print", "C"]])).to_json)
  end

  it "buffers OSC strings" do
    spy    = BufferedSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\e]0;Hello\e\\")
    spy.events.to_json.should eq(JSON.parse(%([["osc_dispatch", "0;Hello", false]])).to_json)
  end

  it "handles OSC buffer overflow gracefully" do
    spy = BufferedSpyHandler.new
    spy.payload_limit = 5
    parser = VT::Parser.new(spy)
    parser.parse("\e]0;Hello World\e\\")
    spy.events.to_json.should eq(JSON.parse(%([["osc_dispatch", "0;Hel", true]])).to_json)
  end

  it "buffers DCS strings" do
    spy    = BufferedSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\eP1;2$qData\e\\")
    spy.events.to_json.should eq(JSON.parse(%([["dcs_dispatch", 113, [[1, false], [2, false]], [36], false, "Data", false]])).to_json)
  end

  it "buffers SOS, PM, APC strings" do
    spy    = BufferedSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\eXsos\e\\\e^pm\e\\\e_apc\e\\")
    spy.events.to_json.should eq(JSON.parse(%([["sos_dispatch", "sos", false], ["pm_dispatch", "pm", false], ["apc_dispatch", "apc", false]])).to_json)
  end
end
