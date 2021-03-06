# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Return" do
  include EventedSpec::SpecHelper
  default_timeout 1.0

  context "when messages are sent to a direct exchange not bound to a queue" do
    let(:messages) { (0..9).map {|i| "Message #{i}" } }

    it "should return all the messages" do
      @returned_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          # need to delete the queue manually because we don't start consumption,
          # hence, no auto-delete
          delayed(0.4) { queue.delete }

          exchange = AMQ::Client::Exchange.new(client, channel, "direct-exchange", :direct).declare.on_return do |method, header, body|
            @returned_messages << method.reply_text
          end

          messages.each do |message|
            exchange.publish(message, AMQ::Protocol::EMPTY_STRING, {}, true, false)
          end
        end

        done(0.6) {
          @returned_messages.size == messages.size
        }
      end

      @returned_messages.should == ["NO_ROUTE"] * messages.size
    end
  end
end
