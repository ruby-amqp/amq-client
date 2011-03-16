require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Get" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "when set 100 messages beforehand" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open { }
        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare(false, false, false, true)
        queue.bind("amq.fanout")

        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
        messages.each do |message|
          exchange.publish(message)
        end
        sleep(0.1)
        messages.size.times do
          queue.get(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
            @received_messages << payload
            done if @received_messages.size == messages.size
          end
        end
      end

      @received_messages.should =~ messages
    end
  end


  context "when sent no messages beforehand" do
    it "should receive nils" do
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open { }
        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare(false, false, false, true)
        queue.bind("amq.fanout")

        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)

        @counter = 0
        10.times do
          queue.get(true) do |header, payload, delivery_tag, redelivered, exchange, routing_key, message_count|
            @counter += 1
            done if @counter == 10
            header.should be_nil
            payload.should be_nil
            delivery_tag.should be_nil
          end
        end

      end
    end

  end
end