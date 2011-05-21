#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)), "..")
require File.join(__dir, "example_helper")

EM.run do
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed", :user => "guest", :password => "guest") do |client|
    puts "Connected, authenticated"

    puts "client.authenticating? => #{client.authenticating?}"


    show_stopper = Proc.new {
      client.disconnect do
        puts
        puts "AMQP connection is now properly closed"
        EM.stop
      end
    }

    Signal.trap "INT",  show_stopper
    Signal.trap "TERM", show_stopper

    EM.add_timer(1, show_stopper)
  end
end
