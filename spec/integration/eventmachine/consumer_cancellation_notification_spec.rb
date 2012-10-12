# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

require "amq/client/extensions/rabbitmq"

describe AMQ::Client::EventMachineClient, "basic.cancel notification" do
  include EventedSpec::SpecHelper
  default_timeout 4

  let(:messages) { (0..99).map {|i| "Message #{i}" } }

  it "works for default consumer" do
    @received_basic_cancel_ok = false
    em_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
        queue.bind("amq.fanout")
        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)

        queue.consume(true) do |amq_method|
          messages.each do |message|
            exchange.publish(message)
          end
        end

        queue.default_consumer.on_cancel do |basic_cancel|
          @received_basic_cancel_ok = true
        end

        delayed(1.0) { queue.delete }

        done(2.5) {
          @received_basic_cancel_ok.should be_true
        }
      end
    end

  end # it "should stop receiving messages after receiving cancel-ok"
end # describe AMQ::Client::EventMachineClient, "Basic.Consume"
