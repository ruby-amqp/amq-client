#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)))
require File.join(__dir, "..", "example_helper")

EM.run do

  show_stopper = Proc.new { EventMachine.stop }
  Signal.trap "TERM", show_stopper
  EM.add_timer(4, show_stopper)


  AMQ::Client::EventMachineClient.connect(:port     => 9689,
                                          :vhost    => "amq_client_testbed",
                                          :user     => "amq_client_gem",
                                          :password => "amq_client_gem_password",
                                          :timeout        => 0.3,
                                          :on_tcp_connection_failure => Proc.new { |settings| puts "Failed to connect, as expected"; EM.stop }) do |client|
    raise "Connected, authenticated. This is not what this example is supposed to do!"
  end
end
