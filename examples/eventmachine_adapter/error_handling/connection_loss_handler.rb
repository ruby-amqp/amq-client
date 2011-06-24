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
                                          :on_tcp_connection_failure => Proc.new { |settings| puts "Failed to connect, this was NOT expected"; EM.stop },
                                          :auto_recovery             => true) do |connection|

    if connection.auto_recovering?
      puts "Connection is auto-recovering..."
    end

    connection.on_tcp_connection_loss do |conn, settings|
      puts "tcp_connection_loss handler kicks in"
      conn.reconnect(false, 2)
    end

    ch1 = AMQ::Client::Channel.new(connection, 1)
    ch1.open do
      puts "Channel 1 open now"
    end
    ch2 = AMQ::Client::Channel.new(connection, 2)
    ch2.open do
      puts "Channel 2 open now"
    end

    4.times do
      q = AMQ::Client::Queue.new(connection, ch1, AMQ::Protocol::EMPTY_STRING)
      q.declare(false, false, false, true)
    end

    2.times do
      q = AMQ::Client::Queue.new(connection, ch2, AMQ::Protocol::EMPTY_STRING)
      q.declare(false, false, false, true)
    end


    # connection.on_recovery do |conn, settings|
    #   puts "Recovered!"
    # end

    show_stopper = Proc.new {
      connection.disconnect { puts "Disconnected. Exiting…"; EventMachine.stop }
    }

    Signal.trap "TERM", show_stopper
    EM.add_timer(30, show_stopper)


    puts "Connected, authenticated. To really exercise this example, shut AMQP broker down for a few seconds. If you don't it will exit gracefully in 30 seconds."
  end
end
