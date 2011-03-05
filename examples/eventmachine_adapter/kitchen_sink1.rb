#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

EM.run do
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
    begin
      puts "AMQP connection is open: #{client.connection.server_properties.inspect}"

      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        puts "Channel #{channel.id} is now open!"
      end

      queue = AMQ::Client::Queue.new(client, channel, "amqclient.queue2")
      queue.declare(false, false, false, true) do
        puts "Queue #{queue.name.inspect} is now declared!"
      end

      exchange = AMQ::Client::Exchange.new(client, channel, "amqclient.adapters.em.exchange1", :fanout)
      exchange.declare { puts "Exchange #{exchange.name.inspect} is now declared!" }

      queue.consume do |msg|
        puts msg
      end


      show_stopper = Proc.new {
        puts
        puts "Deleting queue #{queue.name}"
        queue.delete do |_, message_count|
          puts
          puts "Deleted #{queue.name}. It had #{message_count} messages in it."
          puts
          puts "Deleting exchange #{exchange.name}"
          exchange.delete do
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
    rescue Interrupt
      warn "Manually interrupted, terminating ..."
    rescue Exception => exception
      STDERR.puts "\n\e[1;31m[#{exception.class}] #{exception.message}\e[0m"
      exception.backtrace.each do |line|
        line = "\e[0;36m#{line}\e[0m" if line.match(Regexp::quote(File.basename(__FILE__)))
        STDERR.puts "  - " + line
      end
    end
  end
end
