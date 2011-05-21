#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "An example that combines several AMQ operations" do |connection|
  puts "AMQP connection is open: #{connection.server_properties.inspect}"

  channel = AMQ::Client::Channel.new(connection, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"
  end

  queue = AMQ::Client::Queue.new(connection, channel, "amqclient.queue2")
  queue.declare(false, false, false, true) do
    puts "Queue #{queue.name.inspect} is now declared!"
  end

  exchange = AMQ::Client::Exchange.new(connection, channel, "amqclient.adapters.em.exchange1", :fanout)
  exchange.declare { puts "Exchange #{exchange.name.inspect} is now declared!" }

  queue.consume do |consume_ok|
    puts "basic.consume_ok callback has fired for #{queue.name}, consumer_tag = #{consume_ok.consumer_tag}"
  end


  show_stopper = Proc.new {
    puts
    puts "Deleting queue #{queue.name}"
    queue.delete do |delete_ok|
      puts
      puts "Deleted #{queue.name}. It had #{delete_ok.message_count} messages in it."
      puts
      puts "Deleting exchange #{exchange.name}"
      exchange.delete do
        connection.disconnect do
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
