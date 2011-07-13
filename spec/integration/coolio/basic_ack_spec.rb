# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Basic.Ack", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 1

  context "sending 100 messages" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should receive & acknowledge all the messages" do
      @received_messages = []
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          queue.bind("amq.fanout")

          queue.consume do |_, consumer_tag|
            queue.on_delivery do |method, header, payload|
              queue.acknowledge(method.delivery_tag)
              @received_messages << payload
            end

            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
            messages.each do |message|
              exchange.publish(message)
            end
          end # consume
        end # open

        done(0.8) {
          @received_messages.should =~ messages
        }
      end # coolio_amqp_connect
    end # it
  end # context
end # describe
