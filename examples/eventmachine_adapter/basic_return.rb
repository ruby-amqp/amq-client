#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "basic.return example" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    queue = AMQ::Client::Queue.new(client, channel).declare(false, false, false, true)

    exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
    exchange.on_return do |method, header, body|
      puts "Handling a returned message: exchange = #{method.exchange}, reply_code = #{method.reply_code}, reply_text = #{method.reply_text}"
      puts "Body of the returned message: #{body}"
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

    EM.add_timer(1, show_stopper)
  end
end
