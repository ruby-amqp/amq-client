#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Set a queue up for message delivery" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)

    exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
    exchange.on_return do |reply_code, reply_text, exchange_name, routing_key|
      puts "Handling a returned messages: reply_code=#{reply_code}, reply_text=#{reply_text}"
    end

    10.times do |i|
      exchange.publish("Message ##{i}", AMQ::Protocol::EMPTY_STRING, {}, false, true)
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
end
