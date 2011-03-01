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
  AMQ::Client::EventMachineClient.connect(:port => 5672) do |client|
    begin
      puts "Running a block"

      # channel = AMQ::Client::Channel.new(client, 1)
      # channel.open { puts "Channel #{channel.id} is now open!" }

      # queue = AMQ::Client::Queue.new(client, "", channel)
      # queue.declare { puts "Queue #{queue.name.inspect} declared!" }

      # exchange = AMQ::Client::Exchange.new(client, "tasks", :fanout, channel)
      # exchange.declare { puts "Exchange #{exchange.name.inspect} declared!" }

      # until client.connection.closed?
      #   client.receive_async
      #   sleep 1
      # end

      client.disconnect
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

# TODO:
# AMQ::Client.connect(:adapter => :socket)
# Support for frame_max, heartbeat from Connection.Tune
