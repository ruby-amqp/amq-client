require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Return" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "when messages are sent to a direct exchange not bound to a queue" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should return all the messages" do
      @returned_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)

          exchange = AMQ::Client::Exchange.new(client, channel, "direct-exchange", :direct).declare
          exchange.on_return do |method|
            @returned_messages << method.reply_text
            done if @returned_messages.size == messages.size
          end

          messages.each do |message|
            exchange.publish(message, AMQ::Protocol::EMPTY_STRING, {}, false, true)
          end
        end
      end

      @returned_messages.should == ["NO_CONSUMERS"] * messages.size
    end
  end
end