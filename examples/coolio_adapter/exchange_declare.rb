#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Declare a new fanout exchange" do |client|
  puts "AMQP connection is open: #{client.connection.server_properties.inspect}"

  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
  end

  exchange = AMQ::Client::Exchange.new(client, channel, "amqclient.adapters.em.exchange1", :fanout)
  exchange.declare

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
