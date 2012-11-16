# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

require "multi_json"

describe AMQ::Client::EventMachineClient, "Basic.Publish" do
  include EventedSpec::SpecHelper
  default_timeout 21.0

  context "when message size exceeds negotiated frame size" do
    let(:message) { "z" * 1024 * 1024 * 2 }

    it "correctly frames things" do
      @received_messages = []

      @received_messages = []
      em_amqp_connect do |client|
        client.on_error do |conn, connection_close|
          fail "Handling a connection-level exception: #{connection_close.reply_text}"
        end

        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          queue.bind("amq.fanout")

          queue.consume(true) do |amq_method|
            queue.on_delivery do |method, header, payload|
              @received_messages << payload
            end

            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
            EventMachine.add_timer(2.0) do
              30.times do
                Thread.new do
                  exchange.publish(message, queue.name, {}, false, true)
                end
              end
            end
          end

          delayed(15.0) {
            # we don't care about the exact number, just the fact that there are
            # no UNEXPECTED_FRAME connection-level exceptions. MK.
            @received_messages.size.should > 10
            @received_messages.all? {|m| m == message}.should be_true

            done
          }
        end
      end # em_amqp_connect
    end # it
  end # context
end # describe
