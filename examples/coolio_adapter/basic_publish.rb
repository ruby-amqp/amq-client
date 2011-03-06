#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Publish 100 messages using basic.publish" do |client|
  puts "AMQP connection is open: #{client.connection.server_properties.inspect}"

  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
  end

  exchange = AMQ::Client::Exchange.new(client, channel, "amqclient.adapters.em.exchange1", :fanout)
  exchange.declare do
    100.times do
      # exchange.publish("à bientôt!")
      exchange.publish("See you soon!")
    end

    $stdout.flush
  end

  show_stopper = Proc.new {
    client.disconnect do
      puts
      puts "AMQP connection is now properly closed"
      Coolio::Loop.default.stop
    end
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper
end
