#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Set a queue up for message delivery" do |connection|
  channel = AMQ::Client::Channel.new(connection, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
  end

  queue = AMQ::Client::Queue.new(connection, channel)
  queue.declare(false, false, false, true) do
    puts "Server-named, auto-deletable Queue #{queue.name.inspect} is ready"
  end

  queue.bind("amq.fanout") do
    puts "Queue #{queue.name} is now bound to amq.fanout"
  end

  show_stopper = Proc.new {
    connection.disconnect do
      puts
      puts "AMQP connection is now properly closed"
      Coolio::Loop.default.stop
    end
  }


  queue.consume(true) do |consume_ok|
    puts "Subscribed for messages routed to #{queue.name}, consumer tag is #{consume_ok.consumer_tag}, using no-ack mode"
    puts

    queue.on_delivery do |basic_deliver, header, payload|
      puts "Got a delivery:"
      puts "    Delivery tag: #{basic_deliver.delivery_tag}"
      puts "    Header:  #{header.inspect}"
      puts "    Payload: #{payload.inspect}"

      show_stopper.call if basic_deliver.delivery_tag == 100
    end

    exchange = AMQ::Client::Exchange.new(connection, channel, "amq.fanout", :fanout)
    100.times do |i|
      exchange.publish("Message ##{i}")
    end
  end


  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper
end
