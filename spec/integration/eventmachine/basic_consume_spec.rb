# encoding: utf-8
require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Consume" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "sending ASCII messages" do
    let(:messages) { (0..999).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do end
        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare(false, false, false, true)
        queue.bind("amq.fanout")
        queue.consume(true) do |_, consumer_tag|
          queue.on_delivery do |method, header, payload|
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

  context "sending unicode messages" do
    let(:messages) { (0..999).map {|i| "à bientôt! #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do end
        queue = AMQ::Client::Queue.new(client, channel)
        queue.declare(false, false, false, true)
        queue.bind("amq.fanout")
        queue.consume(true) do |_, consumer_tag|
          queue.on_delivery do |method, header, payload|
            if RUBY_VERSION =~ /1\.9/
              # We are receiving binary bytestream, thus we cannot force
              # UTF-8 or any other encoding except ASCII-8BIT, aka BINARY,
              # by default
              payload = payload.force_encoding("UTF-8")
            end
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