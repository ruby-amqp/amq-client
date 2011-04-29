#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.join(File.dirname(File.expand_path(__FILE__)), "..")
require File.join(__dir, "example_helper")

EM.run do
  AMQ::Client::EventMachineClient.connect(:port     => 5672,
                                          :vhost    => "/amq_client_testbed",
                                          :user     => "amq_client_gem",
                                          :password => "a password that is incorrect #{Time.now.to_i}", :on_possible_authentication_failure => Proc.new { |settings|
                                            puts "Authentication failed, as expected, settings are: #{settings.inspect}"

                                            EventMachine.stop
                                          }) do |client|
    raise "Should not really be executed"
  end
end
