#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Activate or deactivate channel delivery using channel.flow" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    AMQ::Client::Queue.new(client, channel).declare(false, false, false, true) do |q, _, _, _|
      puts "flow is now #{channel.flow_is_active? ? 'on' : 'off'}"

      channel.flow(false) do |_, flow_activity|
        puts "flow is now #{flow_activity ? 'on' : 'off'}"
      end

      sleep 0.1
      channel.flow(true) do |_, flow_activity|
        puts "flow is now #{flow_activity ? 'on' : 'off'}"
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
  end
end
