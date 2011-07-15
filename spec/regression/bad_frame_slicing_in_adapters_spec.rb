# encoding: binary

require 'spec_helper'
require 'integration/coolio/spec_helper'
require 'integration/eventmachine/spec_helper'

describe "AMQ::Client::CoolioClient", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 1

  let(:message) { "Message with xCE \xCE" }

  it "should receive the message with xCE byte in it without errors" do
    coolio_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do end
      queue = AMQ::Client::Queue.new(client, channel)
      queue.declare(false, false, false, true)
      queue.bind("amq.fanout")
      queue.consume(true) do |_, consumer_tag|
        queue.on_delivery do |method, header, payload|
          @received_message = payload
          done
        end

        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
        exchange.publish(message)
      end
    end

    @received_message.should == message
  end
end

describe AMQ::Client::EventMachineClient do
  include EventedSpec::SpecHelper
  default_timeout 1

  let(:message) { "Message with xCE \xCE" }

  it "should receive the message with xCE byte in it without errors" do
    em_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do end
      queue = AMQ::Client::Queue.new(client, channel)
      queue.declare(false, false, false, true)
      queue.bind("amq.fanout")
      queue.consume(true) do |_, consumer_tag|
        queue.on_delivery do |method, header, payload|
          @received_message = payload
          done
        end

        exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
        exchange.publish(message)
      end
    end

    @received_message.should == message
  end
end
