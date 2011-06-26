#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)))
require File.join(__dir, "..", "example_helper")


EM.run do
  AMQ::Client::EventMachineClient.connect(:port     => 5672,
                                          :vhost    => "amq_client_testbed",
                                          :user     => "amq_client_gem",
                                          :password => "amq_client_gem_password",
                                          :timeout        => 0.3,
                                          :on_tcp_connection_failure => Proc.new { |settings| puts "Failed to connect, this was NOT expected"; EM.stop }) do |connection|

    if connection.auto_recovering?
      puts "Connection is auto-recovering..."
    end

    ch1 = AMQ::Client::Channel.new(connection, 1)
    ch1.on_error do |ch, channel_close|
      raise channel_close.reply_text
    end
    ch1.open do
      puts "Channel 1 open now"
    end
    if ch1.auto_recovering?
      puts "Channel 1 is auto-recovering"
    end
    ch1.on_recovery do |c|
      puts "Channel #{c.id} has recovered"
    end

    ch2 = AMQ::Client::Channel.new(connection, 2)
    ch2.on_error do |ch, channel_close|
      raise channel_close.reply_text
    end
    ch2.open do
      puts "Channel 2 open now"
    end
    if ch2.auto_recovering?
      puts "Channel 2 is auto-recovering"
    end


    queues = Array.new(4) do
      q = AMQ::Client::Queue.new(connection, ch1, AMQ::Protocol::EMPTY_STRING)
      q.declare(false, false, false, true) do
        q.consume { puts "Added a consumer on #{q.name}"; q.on_delivery { |*args| puts(args.inspect) } }
      end

      q.on_recovery { |_| puts "Queue #{q.name} has recovered" }

      q
    end

    x  = AMQ::Client::Exchange.new(connection, ch1, "amqclient.examples.exchanges.fanout", :fanout)
    x2 = AMQ::Client::Exchange.new(connection, ch1, "amq.fanout", :fanout)
    x.declare(false, false, true)
    x.after_connection_interruption { |x| puts "Exchange #{x.name} has reacted to connection interruption" }
    x.after_recovery { |x| puts "Exchange #{x.name} has recovered" }
    queues.each { |q| q.bind(x) }


    connection.on_tcp_connection_loss do |conn, settings|
      puts "Trying to reconnect..."
      conn.reconnect(false, 2)
    end

    connection.on_recovery do |conn, settings|
      puts "Connection recovered"
    end

    show_stopper = Proc.new {
      connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
    }

    Signal.trap "TERM", show_stopper
    Signal.trap "INT",  show_stopper
    EM.add_timer(30, show_stopper)


    puts "Connected, authenticated. To really exercise this example, shut AMQP broker down for a few seconds. If you don't it will exit gracefully in 30 seconds."
  end
end
