#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "amq/client/adapters/socket"
require "amq/client/amqp/queue"

AMQ::SocketClient.connect(:port => 5672) do |client|
  client.handshake

  client.get_frame # Start/Start-Ok
  client.get_frame # Tune/Tune-Ok

  # queue = AMQ::Client::Queue.new(client, "", 1)
  # queue.declare { puts "Queue declared!" }

  sleep 2 # connection is closed immediately, why?
end
