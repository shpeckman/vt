# spec/utf8_spec.cr
require "./spec_helper"

class UTF8DecoderSpy
  include VT::UTF8

  def feed(bytes : Array(UInt8))
    chars = Array(Char).new
    bytes.each do |b|
      c = decode_byte(b)
      chars << c if c
    end
    chars
  end
end

describe VT::UTF8 do
  it "decodes ascii" do
    UTF8DecoderSpy.new.feed([65_u8, 66_u8]).should eq(['A', 'B'])
  end

  it "decodes 2-byte char" do
    UTF8DecoderSpy.new.feed([0xC2_u8, 0xA2_u8]).should eq(['¢'])
  end

  it "decodes 3-byte char" do
    UTF8DecoderSpy.new.feed([0xE2_u8, 0x82_u8, 0xAC_u8]).should eq(['€'])
  end

  it "decodes 4-byte char" do
    UTF8DecoderSpy.new.feed([0xF0_u8, 0x90_u8, 0x8D_u8, 0x88_u8]).should eq(['𐍈'])
  end

  it "replaces invalid byte sequences" do
    UTF8DecoderSpy.new.feed([0xFF_u8]).should eq(['\uFFFD'])
  end
end
