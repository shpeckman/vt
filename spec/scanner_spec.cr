# spec/scanner_spec.cr
require "./spec_helper"

describe VT::Scanner do
  it "scans strings" do
    scanner = VT::Scanner.new("foo;bar;baz")
    scanner.next_str.should eq("foo")
    scanner.next_str.should eq("bar")
    scanner.next_str.should eq("baz")
    scanner.complete?.should be_true
  end

  it "scans integers" do
    scanner = VT::Scanner.new("123;-456;0")
    scanner.next_i32.should eq(123)
    scanner.next_i32.should eq(-456)
    scanner.next_i32.should eq(0)
    scanner.complete?.should be_true
  end

  it "scans unsigned integers" do
    scanner = VT::Scanner.new("123;456")
    scanner.next_u32.should eq(123)
    scanner.next_u32.should eq(456)
    scanner.complete?.should be_true
  end

  it "scans booleans" do
    scanner = VT::Scanner.new("1;0;1")
    scanner.next_bool.should be_true
    scanner.next_bool.should be_false
    scanner.next_bool.should be_true
    scanner.complete?.should be_true
  end

  it "handles invalid sequences" do
    scanner = VT::Scanner.new("123;abc")
    scanner.next_i32.should eq(123)
    scanner.next_i32.should eq(0)
    scanner.valid?.should be_false
  end

  it "extracts actions" do
    scanner = VT::Scanner.new("A;B")
    scanner.next_action.should eq(65)
    scanner.next_action.should eq(66)
    scanner.complete?.should be_true
  end
end
