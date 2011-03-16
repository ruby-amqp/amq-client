#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Declare a new fanout exchange" do |client|
  puts "AMQP connection is open: #{client.connection.server_properties.inspect}"

  channel = AMQ::Client::Channel.new(client, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"

    exchange_name = "amqclient.adapters.em.exchange"

    10.times do
      exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
      exchange.declare
    end

    exchange2 = AMQ::Client::Exchange.new(client, channel, exchange_name + "-2", :fanout)
    exchange2.declare

    exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
    exchange.declare do
      puts "Channel is aware of the following exchanges: #{channel.exchanges.keys.join(', ')}"
    end

    show_stopper = Proc.new {
      exchange.delete do
        puts "Exchange #{exchange.name} was successfully deleted"
        exchange2.delete do
          puts "Exchange #{exchange2.name} was successfully deleted"

          client.disconnect do
            puts
            puts "AMQP connection is now properly closed"
            EM.stop
          end
        end
      end
    }

    Signal.trap "INT",  show_stopper
    Signal.trap "TERM", show_stopper

    EM.add_timer(1, show_stopper)
  end
end
