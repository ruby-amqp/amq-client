# encoding: utf-8
require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Consume" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "sending ascii text" do
    let(:messages) { (0..999).map {|i| "Message #{i}" } }

    it "should send all the messages" do
      @sent_messages = 0
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do end
        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare(false, false, false, true)
        queue.bind("amq.fanout")
        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
        messages.each do |message|
          exchange.publish(message)
          @sent_messages += 1
          done(0.25) if @sent_messages == messages.size
        end
      end
      @sent_messages.should == messages.size
    end
  end

  context "sending unicode text" do
    let(:messages) { (0..999).map {|i| "à bientôt! #{i}" } }

    it "should send all the messages" do
      @sent_messages = 0
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do end
        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
        messages.each do |message|
          exchange.publish(message)
          @sent_messages += 1
          done(0.25) if @sent_messages == messages.size
        end
      end
      @sent_messages.should == messages.size
    end
  end
end