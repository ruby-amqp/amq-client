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

    connection.on_tcp_connection_loss do |conn, settings|
      puts "Trying to reconnect..."
      conn.reconnect_to(:host => "dev.rabbitmq.com")
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
