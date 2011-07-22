# encoding: utf-8
require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Tx.Rollback" do
  include EventedSpec::SpecHelper
  default_timeout 4
  let(:message) { "Hello, world!" }
  it "should cancel all the changes done during transaction" do
    pending("Need to figure out details with AMQP protocol on that matter")
    received_messages = []
    em_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
        queue = AMQ::Client::Queue.new(client, channel)

        queue.declare(false, false, false, true) do
          queue.bind(exchange)
        end

        channel.tx_select do
          done(0.1)
          queue.consume(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
            received_messages << message
          end

          exchange.publish(message)
          channel.tx_rollback
        end
      end
    end
    received_messages.should == []
  end
end