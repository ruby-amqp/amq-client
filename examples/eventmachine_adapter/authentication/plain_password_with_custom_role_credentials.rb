#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)), "..")
require File.join(__dir, "example_helper")

EM.run do
  AMQ::Client::EventMachineClient.connect(:port     => 5672,
                                          :vhost    => "/amq_client_testbed",
                                          :user     => "amq_client_gem",
                                          :password => "amq_client_gem_password") do |client|
    puts "Connected, authenticated"


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
