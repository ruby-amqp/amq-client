#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "amq/client/adapters/event_machine"
require "amq/client/amqp/queue"
require "amq/client/amqp/exchange"

EM.run do
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
    begin
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        puts "Channel #{channel.id} is now open!"
      end

      queue = AMQ::Client::Queue.new(client, channel, "amqclient.queue2")
      queue.declare do
        puts "Queue #{queue.name.inspect} is now declared!"
      end

      # exchange = AMQ::Client::Exchange.new(client, channel, "amqclient.exchange2", :fanout)
      # exchange.declare do
      #   puts "Exchange #{queue.name.inspect} (fanout) is now declared!"
      # end

      queue.bind("amq.fanout") do
        puts "Queue #{queue.name} is now bound to amq.fanout"
      end


      show_stopper = Proc.new {
        puts
        puts "Deleting queue #{queue.name}"
        queue.delete do |_, message_count|
          puts "Deleted."
          puts
          client.disconnect do
            puts
            puts "AMQP connection is now properly closed"
            EM.stop
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
