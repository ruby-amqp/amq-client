# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Cancel" do
  include EventedSpec::SpecHelper
  default_timeout 4

  let(:messages) { (0..99).map {|i| "Message #{i}" } }

  it "should stop receiving messages after receiving cancel-ok" do
    @received_messages        = []
    @received_basic_cancel_ok = false
    em_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
        queue.bind("amq.fanout")
        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)

        queue.consume(true) do |amq_method|
          queue.on_delivery do |method, header, payload|
            @received_messages << payload
          end

          messages.each do |message|
            exchange.publish(message)
          end
        end

        delayed(1.5) {
          @received_messages.should =~ messages
          queue.cancel do
            @received_basic_cancel_ok = true
            exchange.publish("Extra message, should not be received")
          end
        }

        done(2.5) {
          @received_messages.should =~ messages
          @received_basic_cancel_ok.should be_true
        }
      end
    end

  end # it "should stop receiving messages after receiving cancel-ok"
end # describe AMQ::Client::EventMachineClient, "Basic.Consume"
