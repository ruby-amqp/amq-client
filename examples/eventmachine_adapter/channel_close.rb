#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Open and then close AMQ channel" do |connection|
  puts "AMQP connection is open: #{connection.server_properties.inspect}"

  channel = AMQ::Client::Channel.new(connection, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
    puts "Lets close it."
    channel.close do
      puts "Closed channel ##{channel.id}"
      puts
      connection.disconnect do
        puts
        puts "AMQP connection is now properly closed"
        EM.stop
      end
    end
  end
end
