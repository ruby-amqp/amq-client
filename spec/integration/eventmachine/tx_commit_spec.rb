# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Tx.Commit" do

  #
  # Environment
  #

  include EventedSpec::SpecHelper
  default_timeout 4

  let(:message) { "Hello, world!" }


  #
  # Examples
  #

  it "should confirm transaction completeness" do
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
          queue.consume(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
            received_messages << message
            done
          end

          exchange.publish(message)
          channel.tx_commit
        end
      end # em_amqp_connect

    end
    received_messages.should == [message]
  end # it
end # describe