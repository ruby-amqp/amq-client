# encoding: utf-8
require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Tx.*" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "Tx.Commit" do
    let(:message) { "Hello, world!" }
    it "should confirm transaction completeness" do
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
          queue = AMQ::Client::Queue.new(client, channel)

          queue.declare(false, false, false, true) do
            queue.bind(exchange)
          end

          channel.tx_select do
            exchange.publish(message)
            channel.tx_commit do
              queue.get(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
                payload.should == message
                done
              end
            end
          end
       end
      end
    end
  end


  context "Tx.Rollback" do
    let(:message) { "Hello, world!" }
    it "should cancel all the changes done during transaction" do
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
          queue = AMQ::Client::Queue.new(client, channel)

          queue.declare(false, false, false, true) do
            queue.bind(exchange)
          end

          channel.tx_select do
            exchange.publish(message)
            channel.tx_rollback do
              queue.get(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
                payload.should == nil
                done
              end
            end
          end
       end
      end
    end
  end
end