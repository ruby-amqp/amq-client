# encoding: utf-8

Bundler.setup
Bundler.require(:default)
$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "amq/client/adapters/coolio"
require "amq/client/adapters/event_machine"
require "amq/client/queue"
require "amq/client/exchange"

TOTAL_MESSAGES = 10000
# Short messages
# Cool.io
coolio_start = Time.now
AMQ::Client::CoolioClient.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
  received_messages = 0
  channel = AMQ::Client::Channel.new(client, 1)
  channel.open { }
  queue = AMQ::Client::Queue.new(client, channel)
  queue.declare(false, false, false, true) { }

  queue.bind("amq.fanout") { }

  queue.consume(true) do |_, consumer_tag|

    queue.on_delivery do |_, header, payload, consumer_tag, delivery_tag, redelivered, exchange, routing_key|
      received_messages += 1
      if received_messages == TOTAL_MESSAGES
        client.disconnect do
          Coolio::Loop.default.stop
        end
      end
    end

    exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
    TOTAL_MESSAGES.times do |i|
      exchange.publish("Message ##{i}")
    end
  end
end
cool.io.run
coolio_finish = Time.now

# Eventmachine
em_start = Time.now
EM.run do
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
    received_messages = 0
    channel = AMQ::Client::Channel.new(client, 1)
    channel.open { }
    queue = AMQ::Client::Queue.new(client, channel)
    queue.declare(false, false, false, true) { }

    queue.bind("amq.fanout") { }

    queue.consume(true) do |_, consumer_tag|

      queue.on_delivery do |_, header, payload, consumer_tag, delivery_tag, redelivered, exchange, routing_key|
        received_messages += 1
        if received_messages == TOTAL_MESSAGES
          client.disconnect do
            EM.stop
          end
        end
      end

      exchange = AMQ::Client::Exchange.new(client, channel, "amq.fanout", :fanout)
      TOTAL_MESSAGES.times do |i|
        exchange.publish("Message ##{i}")
      end
    end
  end
end
em_finish = Time.now

puts "Results for #{TOTAL_MESSAGES} messages:"
puts "\tcool.io adapter: #{sprintf("%.3f", coolio_finish - coolio_start)}s"
puts "\teventmachine adapter: #{sprintf("%.3f", em_finish - em_start)}s"