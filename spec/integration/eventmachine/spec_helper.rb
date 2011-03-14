require "amq/client/adapters/event_machine"
require "amq/client/amqp/queue"
require "amq/client/amqp/exchange"
require "evented-spec"

def em_amqp_connect(&block)
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed", :frame_max => 65536, :heartbeat_interval => 1) do |client|
    yield client
  end
end