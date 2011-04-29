#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)), "..")
require File.join(__dir, "example_helper")

begin
  EventMachine.run do
    AMQ::Client::EventMachineClient.connect(:port     => 5672,
                                            :vhost    => "/amq_client_testbed",
                                            :user     => "amq_client_gem",
                                            :password => "a password that is incorrect #{Time.now.to_i}") do |client|
      raise "Should not really be executed"
    end
  end
rescue AMQ::Client::PossibleAuthenticationFailureError => afe
  puts "Authentication failed, as expected. Caught #{afe.inspect}"
  EventMachine.stop if EventMachine.reactor_running?
end
