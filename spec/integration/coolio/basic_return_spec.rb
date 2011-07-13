# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Basic.Return", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 1.0

  context "when messages are sent to a direct exchange not bound to a queue" do
    let(:messages) { (0..9).map {|i| "Message #{i}" } }

    it "should return all the messages" do
      @returned_messages = []
      coolio_amqp_connect do |client|
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
            exchange.publish(message, AMQ::Protocol::EMPTY_STRING, {}, false, true)
          end
        end

        done(0.6) { @returned_messages.size == messages.size }
      end

      @returned_messages.should == ["NO_CONSUMERS"] * messages.size
    end
  end
end