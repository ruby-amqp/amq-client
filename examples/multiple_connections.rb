#!/usr/bin/env ruby
# encoding: utf-8

# Each connection respond to a TCP connection,
# hence we need to use more client.connect calls.

AMQ::SocketClient.connect(:port => 5672) do |client|
  # ...
end

AMQ::SocketClient.connect(:port => 5672) do |client|
  # ...
end
