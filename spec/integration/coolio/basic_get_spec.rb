# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Basic.Get", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 1

  context "when set two messages beforehand" do
    let(:messages) { ["message 1", "message 2"] }

    it "synchronously fetches all the messages" do
      @received_messages = []
      coolio_amqp_connect do |client|
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

            delayed(0.5) {
              # need to delete the queue manually because #get doesn't count as consumption,
              # hence, no auto-delete
              queue.delete
            }
            done(0.75) {
              @received_messages.should =~ messages
            }
          end
        end
      end
    end
  end


  context "when sent no messages beforehand" do
    it "should receive nils" do
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel)
          queue.declare(false, false, false, true)
          queue.bind("amq.fanout")

          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)

          queue.get(true) do |method, header, payload|
            header.should be_nil
            payload.should be_nil

            queue.delete
            done(0.5)
          end # get
        end
      end # em_amqp_connect
    end # it

  end # context
end