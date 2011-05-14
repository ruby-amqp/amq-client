#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)), "..")
require File.join(__dir, "example_helper")

begin
  EventMachine.run do

    show_stopper = Proc.new {
      EM.stop
    }

    Signal.trap "INT",  show_stopper
    Signal.trap "TERM", show_stopper

    EventMachine.add_timer(4, show_stopper)

    AMQ::Client::EventMachineClient.connect(:port     => 9689,
                                            :vhost    => "/a/b/c/#{rand}/d/#{Time.now.to_i}",
                                            :user     => "amq_client_gem",
                                            :password => "amq_client_gem_password",
                                            :timeout        => 0.3) do |client|
      raise "Connected, authenticated. This is not what this example is supposed to do!"
    end
  end
rescue AMQ::Client::TCPConnectionFailed => e
  puts "TCP connection has failed, as expected. Shutting down…"
  EventMachine.stop if EventMachine.reactor_running?
end