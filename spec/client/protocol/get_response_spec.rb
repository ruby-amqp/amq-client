# encoding: utf-8

require "spec_helper"

require "amq/protocol/client"
require "amq/protocol/get_response"
# require "amq/protocol/frame"
#
# # We have to use Kernel#load so extensions to the
# # Logging module from client.rb will be overridden.
# load "amq/client/framing/string/frame.rb"

describe AMQ::Protocol::GetResponse do
  describe "when method is GetOk" do
    before  { @method = AMQ::Protocol::Basic::GetOk.new("dtag", true, "tasks", "foo", 1) }
    subject { AMQ::Protocol::GetResponse.new(@method) }

    it "should NOT be #empty?" do
      should_not be_empty
    end

    it "should have #delivery_tag" do
      subject.delivery_tag.should eql("dtag")
    end

    it "should have #redelivered" do
      subject.redelivered.should be_true
    end

    it "should have #exchange" do
      subject.exchange.should eql("tasks")
    end

    it "should have #routing_key" do
      subject.routing_key.should eql("foo")
    end

    it "should have #message_count" do
      subject.message_count.should eql(1)
    end

    it "should NOT have #cluster_id" do
      subject.cluster_id.should be_nil
    end
  end

  describe "when method is GetEmpty" do
    before  { @method = AMQ::Protocol::Basic::GetEmpty.new("ID") }
    subject { AMQ::Protocol::GetResponse.new(@method) }

    it "should be #empty?" do
      should be_empty
    end

    it "should NOT have #delivery_tag" do
      subject.delivery_tag.should be_nil
    end

    it "should NOT have #redelivered" do
      subject.redelivered.should be_nil
    end

    it "should NOT have #exchange" do
      subject.exchange.should be_nil
    end

    it "should NOT have #routing_key" do
      subject.routing_key.should be_nil
    end

    it "should NOT have #message_count" do
      subject.message_count.should be_nil
    end

    it "should have #cluster_id" do
      subject.cluster_id.should eql("ID")
    end
  end
end
