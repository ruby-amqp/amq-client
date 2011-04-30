#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Bind a new queue to amq.fanout" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
  end

  AMQ::Client::Queue.new(client, channel, "amqclient.queue2").declare do |queue, declare_ok|
    puts queue.class.name
    puts "Queue #{queue.name.inspect} is now declared!"

    queue.bind("amq.fanout") do
      puts "Queue #{queue.name} is now bound to amq.fanout."
      puts
      puts "Deleting queue #{queue.name}"
      queue.delete do |message_count|
        puts "Deleted."
        puts
        client.disconnect do
          puts
          puts "AMQP connection is now properly closed"
          EM.stop
        end
      end
    end
  end
end
