#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Purge a queue and announce how many messages it had" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"

    4.times do
      q = AMQ::Client::Queue.new(client, channel, AMQ::Protocol::EMPTY_STRING)
      q.declare(false, false, false, true)
    end

    begin
      q = AMQ::Client::Queue.new(client, channel, AMQ::Protocol::EMPTY_STRING)
      q.declare(false, false, false, true, true)
    rescue ArgumentError => e
      puts "Non-sensical declaration of a server-named queue with nowait did not slip through, great"
    end
    

    queue = AMQ::Client::Queue.new(client, channel, AMQ::Protocol::EMPTY_STRING)
    queue.declare(false, false, false, true) do
      puts "Queue #{queue.name.inspect} is now declared!"

      puts "Channel is aware of the following queues: #{channel.queues.map { |q| q.name }.join(', ')}"

      client.disconnect { EM.stop }
    end
  end
end
