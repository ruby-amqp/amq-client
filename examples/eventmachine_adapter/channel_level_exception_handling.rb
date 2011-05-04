#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Channel-level exception handling" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open"

    show_stopper = Proc.new {
      client.disconnect do
        puts
        puts "AMQP connection is now properly closed"
        EM.stop
      end
    }



    channel.on_error do |ch, close|
      puts "Oops, there is a channel-level exception: #{close.inspect}"

      EM.add_timer(1.2) { show_stopper.call }
    end

    # amq.* names are reserevd so this causes a channel-level exception. MK.
    x = AMQ::Client::Exchange.new(client, channel, "amq.client.examples.extensions.x1", :direct)
    x.declare(false, false, false, true, false)


    EM.add_timer(1) do
      if channel.closed?
        puts "1 second later channel #{channel.id} is closed"
      end
    end

    Signal.trap "INT",  show_stopper
    Signal.trap "TERM", show_stopper

    EM.add_timer(2, show_stopper)
  end
end