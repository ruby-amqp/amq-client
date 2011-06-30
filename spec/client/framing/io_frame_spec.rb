# encoding: binary

require "spec_helper"
require "stringio"

# We need to require AMQ-Protocol manually.
# In the library this is required in the file
# amq/client.rb, but this is a unit test and
# we don't want to mess around with unecessary
# dependencies.
require "amq/protocol/client"
require "amq/protocol/frame"

# We have to use Kernel#load so extensions to the
# Logging module from client.rb will be overridden.
load "amq/client/framing/io/frame.rb"

describe AMQ::Client::Framing::IO do
  subject do
    AMQ::Client::Framing::IO::Frame
  end

  # Created by:
  # frame = AMQ::Protocol::Queue::Declare.encode(1, "tasks", false, false, false, false, {})
  # frame.encode
  # frame.payload
  before do
    data = ["\x01\x00\x00\x00\x00\x00\b"]
    data << "\x00\n\x00(\x01/\x00\x00"
    data << "\xCE"
    @io = StringIO.new(data.join)

    subject.stub(:decode_header).with(data.first).and_return([1, 0, data[1].bytesize])
  end

  it "should be able to decode frame type" do
    subject.decode(@io).should be_kind_of(AMQ::Protocol::MethodFrame)
  end

  it "should be able to decode channel" do
    subject.decode(@io).channel.should eql(0)
  end

  it "should be able to decode payload" do
    subject.decode(@io).payload.should eql("\x00\n\x00(\x01/\x00\x00")
  end

  context "if the frame length is miscalculated" do
    it "should raise an error"
  end


  context "if frame doesn't end with FINAL_OCTET" do
    it "should raise an error" do
      data = @io.read[0..-2] + "too long" + "\xCE"
      io   = StringIO.new(data)
      lambda { subject.decode(io) }.should raise_error(AMQ::Client::NoFinalOctetError)
    end
  end
end
