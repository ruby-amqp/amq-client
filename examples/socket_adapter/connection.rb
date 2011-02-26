#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "amq/client/adapters/socket"
require "amq/client/amqp/queue"
require "amq/client/amqp/exchange"

AMQ::Client::SocketClient.connect(:port => 5672) do |client|
  begin
    client.handshake

    # Ruby developers are used to use blocks usually synchronously
    # (so they are called +/- immediately), but this is NOT the case!
    # We always have to wait for the response from the broker, so think
    # about the following blocks are true callbacks as you know them
    # from JavaScript (i. e. window.onload = function () {}).

    # The only exception is when you use {nowait: true}, then the
    # callback is called immediately.
    channel = AMQ::Client::Channel.new(client, 1)
    channel.open { puts "Channel #{channel.id} opened!" }

    queue = AMQ::Client::Queue.new(client, "", channel)
    queue.declare { puts "Queue #{queue.name.inspect} declared!" }

    exchange = AMQ::Client::Exchange.new(client, "tasks", :fanout, channel)
    exchange.declare { puts "Exchange #{exchange.name.inspect} declared!" }

    until client.connection.closed?
      client.receive_async
      sleep 1
    end
  rescue Interrupt
    warn "Manually interrupted, exciting ..."
  rescue Exception => exception
    STDERR.puts "\n\e[1;31m[#{exception.class}] #{exception.message}\e[0m"
    exception.backtrace.each do |line|
      line = "\e[0;36m#{line}\e[0m" if line.match(Regexp::quote(File.basename(__FILE__)))
      STDERR.puts "  - " + line
    end
  end
end

# TODO:
# AMQ::Client.connect(:adapter => :socket)
# Support for frame_max, heartbeat from Connection.Tune
