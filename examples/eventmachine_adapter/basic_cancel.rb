#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Set a queue up for message delivery" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    queue = AMQ::Client::Queue.new(client, channel)
    queue.declare(false, false, false, true)

    queue.bind("amq.fanout") do
      puts "Queue #{queue.name} is now bound to amq.fanout"
    end

    queue.consume(true) do |consumer_tag|
      queue.on_delivery do |method, header, payload|
        puts "Received #{payload}"
      end

      exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
      100.times do |i|
        exchange.publish("Message ##{i}")
      end


      queue.cancel do
        100.times do |i|
          exchange.publish("Message ##{i} that MUST NOT have been routed to #{queue.name}")
        end
      end
    end
  end


  show_stopper = Proc.new {
    client.disconnect do
      puts
      puts "AMQP connection is now properly closed"
      EM.stop
    end
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

    EM.add_timer(1, show_stopper)
end
