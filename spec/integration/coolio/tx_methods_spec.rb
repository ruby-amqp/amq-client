# encoding: utf-8
require 'spec_helper'
require 'integration/coolio/spec_helper'

describe AMQ::Client::Coolio, "Tx.*" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "Tx.Commit" do
    let(:message) { "Hello, world!" }
    it "should confirm transaction completeness" do
      received_messages = []
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
          queue = AMQ::Client::Queue.new(client, channel)

          queue.declare(false, false, false, true) do
            queue.bind(exchange)
          end

          channel.tx_select do
            queue.consume(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
              received_messages << message
              done
            end

            exchange.publish(message)
            channel.tx_commit
          end
        end
      end
      received_messages.should == [message]
    end
  end


  context "Tx.Rollback" do
    let(:message) { "Hello, world!" }
    it "should cancel all the changes done during transaction" do
      received_messages = []
      coolio_amqp_connect do |client|
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
end