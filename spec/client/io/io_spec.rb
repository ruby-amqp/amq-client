# encoding: utf-8

require "spec_helper"
require "stringio"

# We need to require AMQ-Protocol manually.
# In the library this is implemented by
# AMQ::Client.load_amq_protocol method,
# but this is a unit test and we don't want
# to mess around with unecessary dependencies.
require "amq/protocol/frame"
require "amq/client/io/io"

describe AMQ::Client::IOAdapter do
  subject do
    TestIoAdapter.extend(AMQ::Client::IOAdapter)
  end

  # Created by:
  # frame = AMQ::Protocol::Queue::Declare.encode(1, "tasks", false, false, false, false, {})
  # frame.encode
  # frame.payload
  before do
    data = ["\x01\x00\x01\x00\x00\x00\x11"]
    data << "\x002\x00\n\x00\x00\x05tasks\x00\x00\x00\x00\x00"
    data << "\xCE"
    @io = StringIO.new(data.join)

    TestIoAdapter.stub(:decode_header).with(data.first).and_return([1, data[1], 12])
  end

  it "should be able to decode frame type" do
    subject.decode(@io).type.should eql(1)
  end

  it "should be able to decode channel" do
    subject.decode(@io).type.should eql(12)
  end

  it "should be able to decode payload" do
    subject.decode(@io).type.should eql("\x002\x00\n\x00\x00\x05tasks\x00\x00\x00\x00\x00")
  end

  it "should raise an error if the frame doesn't end with FINAL_OCTET" do
    data = @io.read[0..-2] + "too long" + "\xCE"
    io   = StringIO.new(data)
    lambda { subject.decode(io) }.should raise_error(AMQ::Client::BadLengthError)
  end
end
