# encoding: utf-8

require "spec_helper"

# We need to require AMQ-Protocol manually.
# In the library this is required in the file
# amq/client.rb, but this is a unit test and
# we don't want to mess around with unecessary
# dependencies.
require "amq/protocol/client"
require "amq/protocol/frame"

# We have to use Kernel#load so extensions to the
# Logging module from client.rb will be overridden.
load "amq/client/framing/string/frame.rb"

describe AMQ::Client::Framing::String do
  subject do
    AMQ::Client::Framing::String::Frame
  end

  # Created by:
  # frame = AMQ::Protocol::Queue::Declare.encode(1, "tasks", false, false, false, false, {})
  # frame.encode
  # frame.payload
  before do
    data = ["\x01\x00\x00\x00\x00\x00\b"]
    data << "\x00\n\x00(\x01/\x00\x00"
    data << "\xCE"
    @string = data.join

    subject.stub(:decode_header).with(data.first).and_return([1, 0, data[1].bytesize])
  end

  it "should be able to decode frame type" do
    subject.decode(@string).should be_kind_of(AMQ::Protocol::MethodFrame)
  end

  it "should be able to decode channel" do
    subject.decode(@string).channel.should eql(0)
  end

  it "should be able to decode payload" do
    subject.decode(@string).payload.should eql("\x00\n\x00(\x01/\x00\x00")
  end

  it "should raise an error if the frame length is miscalculated" do
    data = @string[0..-2] + "too long" + "\xCE"
    string   = String.new(data)
    lambda { subject.decode(string) }.should raise_error(AMQ::Client::BadLengthError)
  end

  it "should raise an error if the frame doesn't end with FINAL_OCTET" do
    string = @string[0..-2] + "x"
    lambda { subject.decode(string) }.should raise_error(AMQ::Client::NoFinalOctetError)
  end
end
