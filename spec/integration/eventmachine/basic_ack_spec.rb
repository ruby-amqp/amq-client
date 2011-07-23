# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Ack" do
  include EventedSpec::SpecHelper
  default_timeout 4

  context "sending 100 messages" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          queue.bind("amq.fanout")

          queue.consume do |amq_method|
            queue.on_delivery do |method, header, payload|
              queue.acknowledge(method.delivery_tag)
              @received_messages << payload
            end

            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
            messages.each do |message|
              exchange.publish(message)
            end
          end

          done(3.5) {
            @received_messages =~ messages
          }
        end
      end
    end
  end
end
