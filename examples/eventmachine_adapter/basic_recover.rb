#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Notify broker about consumer recovery using basic.recover" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    AMQ::Client::Queue.new(client, channel).declare(false, false, false, true) do |q, _, _, _|
      channel.recover do |_|
        puts "basic.recover callback has fired"
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
