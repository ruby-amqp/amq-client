# encoding: utf-8

require "amq/client/adapters/event_machine"
require "amq/client/queue"
require "amq/client/exchange"
require "evented-spec"

case RUBY_VERSION
when "1.8.7" then
  class Array
    alias sample choice
  end
when /^1.9/ then
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

def em_amqp_connect(&block)
  em do
    AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "amq_client_testbed", :frame_max => 65536, :heartbeat_interval => 1) do |client|
      yield client
    end
  end
end
