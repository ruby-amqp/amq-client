#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Set a queue up for message delivery" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
  end

  queue = AMQ::Client::Queue.new(client, channel)
  queue.declare(false, false, false, true) do
    puts "Server-named, auto-deletable Queue #{queue.name.inspect} is ready"
  end

  queue.bind("amq.fanout") do
    puts "Queue #{queue.name} is now bound to amq.fanout"
  end

  EM.add_periodic_timer(0.1) do
    $stdout.flush
  end

  queue.consume(true) do |_, consumer_tag|
    puts "Subscribed for messages routed to #{queue.name}, consumer tag is #{consumer_tag}, using no-ack mode"
    puts

    queue.on_delivery do |_, header, payload|
      puts "Got a delivery:"
      puts "    Header:  #{header.inspect}"
      puts "    Payload: #{payload.inspect}"
    end

    puts "Now lets publish a few hundreds of messages there, shall we"
    exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
    10.times do |i|
      exchange.publish("Message ##{i}")

      puts "Published #{i}"
    end

    $stdout.flush
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
end
