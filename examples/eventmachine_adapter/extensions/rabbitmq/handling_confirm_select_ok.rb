#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "..", "..", "example_helper")

require "amq/client/extensions/rabbitmq/confirm"

amq_client_example "confirm.select (a RabbitMQ extension)" do |client|
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open"

    channel.confirm_select do |select_ok|
      puts "Broker replied with confirm.select_ok"
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
