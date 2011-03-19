#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Commit acknowledgement transaction using tx.commit" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    channel.tx_select do |_|
      channel.tx_commit do |_|
        puts "Transaction on channel #{channel.id} is now committed"
      end
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
