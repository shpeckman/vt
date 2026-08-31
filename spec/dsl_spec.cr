# spec/dsl_spec.cr
require "./spec_helper"

class DSLSpyHandler
  include VT::BaseHandler
  include VT::DSL

  getter matched : String? = nil

  def csi_dispatch(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    on_csi 'm' do
      @matched = "SGR"
    end

    on_csi ['H', 'f'] do
      @matched = "CUP"
    end

    on_csi 'c', intermediates: '>' do
      @matched = "DA2"
    end
  end

  def hook(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    on_dcs 'q', intermediates: '$' do
      @matched = "DECRQSS"
    end
  end
end

describe VT::DSL do
  it "matches single character csi" do
    spy    = DSLSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\e[m")
    spy.matched.should eq("SGR")
  end

  it "matches array character csi" do
    spy    = DSLSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\e[f")
    spy.matched.should eq("CUP")
  end

  it "matches csi with intermediates" do
    spy    = DSLSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\e[>c")
    spy.matched.should eq("DA2")
  end

  it "matches dcs with intermediates" do
    spy    = DSLSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\eP$q\e\\")
    spy.matched.should eq("DECRQSS")
  end

  it "ignores unmatched sequences" do
    spy    = DSLSpyHandler.new
    parser = VT::Parser.new(spy)
    parser.parse("\e[J")
    spy.matched.should be_nil
  end
end
