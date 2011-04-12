require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Basic.Get" do
  include EventedSpec::SpecHelper
  default_timeout 2

  context "with two messages in the queue" do
    let(:messages) { ["message 1", "message 2"] }

    it "synchronously fetches all the messages" do
      @received_messages = []
      em_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)

        channel.open do
          queue = AMQ::Client::Queue.new(client, channel)
          queue.declare(false, false, false, true) do
            queue.bind("amq.fanout") do
              puts "Bound!"

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

              queue.purge {
                puts "Purged the queue"
              }
            end
          end
        end


        done(1.0) {
          @received_messages.should =~ messages
        }
      end # em_amqp_connect
    end # it
  end # context


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
          end # get
        end

        done(0.8)
      end # em_amqp_connect
    end # it

  end # context
end # describe
