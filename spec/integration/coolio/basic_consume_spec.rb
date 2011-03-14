require 'spec_helper'
require 'integration/coolio/spec_helper'

describe AMQ::Client::Coolio do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "sending 100 messages" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      coolio do
        amqp_connect do |client|
          channel = AMQ::Client::Channel.new(client, 1)
          channel.open do end
          queue = AMQ::Client::Queue.new(client, channel)
          queue.declare(false, false, false, true)
          queue.bind("amq.fanout")
          queue.consume(true) do |_, consumer_tag|
            queue.on_delivery do |_, header, payload, consumer_tag, delivery_tag, redelivered, exchange, routing_key|
              @received_messages << payload
              done if @received_messages.size == messages.size
            end

            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
            messages.each do |message|
              exchange.publish(message)
            end
          end
        end
      end

      @received_messages.should =~ messages
    end

  end
end