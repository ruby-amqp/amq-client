#!/usr/bin/env ruby
# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "amq/client/adapters/socket"

AMQ::Client::SocketClient.connect(:host => "localhost") do |client|
  # Socket API is synchronous, so we don't need any callback here:
  tasks = client.queue("tasks", 1)
  tasks.consume do |headers, message| # TODO: this is async, we need to use a loop
    puts ""
  end
end
