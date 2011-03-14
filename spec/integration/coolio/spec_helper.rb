require "amq/client/adapters/coolio"
require "amq/client/amqp/queue"
require "amq/client/amqp/exchange"
require "evented-spec"

def amqp_connect(&block)
  AMQ::Client::Coolio.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
    yield client
  end
end