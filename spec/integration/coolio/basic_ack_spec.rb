require 'spec_helper'
require 'integration/coolio/spec_helper'

describe AMQ::Client::Coolio, "Basic.Ack" do
  include EventedSpec::SpecHelper
  default_timeout 4

  context "sending 100 messages" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open {  }

        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare

        queue.bind("amq.fanout")

        queue.consume do |_, consumer_tag|
          queue.on_delivery do |qu, header, payload, consumer_tag, delivery_tag, redelivered, exchange, routing_key|
            qu.acknowledge(delivery_tag)
            @received_messages << payload
            done if @received_messages.size == messages.size
          end

          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
          messages.each do |message|
            exchange.publish(message)
          end
        end
      end

      @received_messages.should =~ messages
    end

  end

  context "sending 500 messages" do
    let(:messages) { (0..499).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open {  }

        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare

        queue.bind("amq.fanout")

        queue.consume do |_, consumer_tag|
          queue.on_delivery do |qu, header, payload, consumer_tag, delivery_tag, redelivered, exchange, routing_key|
            qu.acknowledge(delivery_tag)
            @received_messages << payload
            done if @received_messages.size == messages.size
          end

          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
          messages.each do |message|
            exchange.publish(message)
          end
        end
      end

      @received_messages.should =~ messages
    end

  end
end