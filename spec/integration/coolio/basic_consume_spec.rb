# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

#
# Note that this spec doesn't test acknowledgements.
# See basic_ack_spec for example with acks
#

describe "AMQ::Client::CoolioClient", "Basic.Consume", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 4

  context "sending 100 messages" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "should receive all the messages" do
      @received_messages = []
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          queue.bind("amq.fanout")

          queue.consume(true) do |amq_method|
            queue.on_delivery do |method, header, payload|
              @received_messages << payload
            end

            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
            messages.each do |message|
              exchange.publish(message)
            end
          end

          done(1.5) {
            @received_messages.should =~ messages
          }
        end
      end
    end # it "should receive all the messages"

    it "should not leave messages in the queues with noack=true" do
      @received_messages = []
      @rereceived_messages = []
      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          channel.qos(0, 1) # Maximum prefetch size = 1
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          queue.bind("amq.fanout")

          # Change noack to false and watch spec fail
          queue.consume(true) do |amq_method|
            queue.on_delivery do |method, header, payload|
              @received_messages << payload
            end

            exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
            messages.each do |message|
              exchange.publish(message)
            end
          end

          # We're opening another channel and starting consuming the same queue,
          # assuming 1.5 secs was enough to receive all the messages
          delayed(1.5) do
            other_channel = AMQ::Client::Channel.new(client, 2)
            other_channel.open do
              other_channel.qos(0, 1) # Maximum prefetch size = 1
              other_queue = AMQ::Client::Queue.new(client, other_channel, queue.name)
              other_queue.consume(true) do |amq_method|
                other_queue.on_delivery do |method, header, payload|
                  @rereceived_messages << payload
                end
              end
            end
          end

        end


        done(2.5) {
          @rereceived_messages.should == []
          @received_messages.should =~ messages
        }
      end
    end # it "should not leave messages in the queues with noack=true"
  end # context "sending 100 messages"
end # describe AMQ::Client::CoolioClient, "Basic.Consume"


describe "Multiple", AMQ::Client::Async::Consumer, :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 4

  context "sharing the same queue with equal prefetch levels" do
    let(:messages) { (0..99).map {|i| "Message #{i}" } }

    it "have messages distributed to them in the round-robin manner" do
      @consumer1_mailbox = []
      @consumer2_mailbox = []
      @consumer3_mailbox = []

      coolio_amqp_connect do |client|
        channel = AMQ::Client::Channel.new(client, 1)
        channel.open do
          queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)
          queue.bind("amq.fanout")

          consumer1 = AMQ::Client::Async::Consumer.new(channel, queue, "#{queue.name}-consumer-#{Time.now}")
          consumer2 = AMQ::Client::Async::Consumer.new(channel, queue)
          consumer3 = AMQ::Client::Async::Consumer.new(channel, queue, "#{queue.name}-consumer-#{rand}-#{Time.now}", false, true)


          consumer1.consume.on_delivery do |method, header, payload|
            @consumer1_mailbox << payload
          end

          consumer2.consume(true).on_delivery do |method, header, payload|
            @consumer2_mailbox << payload
          end

          consumer3.consume(false) do
            puts "Consumer 3 is ready"
          end
          consumer3.on_delivery do |method, header, payload|
            @consumer3_mailbox << payload
          end


          exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
          messages.each do |message|
            exchange.publish(message)
          end
        end

        done(1.5) {
          @consumer1_mailbox.size.should == 34
          @consumer2_mailbox.size.should == 33
          @consumer3_mailbox.size.should == 33
        }
      end
    end # it
  end # context
end # describe
