require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Get" do
  include EventedSpec::SpecHelper
  default_timeout 1

  context "when set two messages beforehand" do
    let(:messages) { ["message 1", "message 2"] }

    it "synchronously fetches all the messages" do
      @received_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)

        channel.open do
          queue = AMQ::Client::Queue.new(client, channel)
          queue.declare(false, false, false, true) do
            queue.bind("amq.fanout")
            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)

            messages.each do |message|
              exchange.publish(message) do
                puts "Published a message: #{message}"
              end
            end

            queue.get(true) do |method, header, payload|
              puts "Got #{payload}"              
              @received_messages << payload
            end
            queue.get(true) do |method, header, payload|
              puts "Got #{payload}"              
              @received_messages << payload
            end

            done(0.6) {
              @received_messages.should =~ messages

              queue.purge
            }
          end
        end
      end
    end
  end


  context "when sent no messages beforehand" do
    it "should receive nils" do
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel)
          queue.declare(false, false, false, true)
          queue.bind("amq.fanout")

          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)

          queue.get(true) do |method, header, payload|
            header.should be_nil
            payload.should be_nil

            done {
              queue.purge
            }
          end # get
        end
      end # em_amqp_connect
    end # it

  end # context
end # describe
