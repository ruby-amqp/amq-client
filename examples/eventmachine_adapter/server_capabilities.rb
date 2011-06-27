#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

amq_client_example "Inspecting server information & capabilities" do |client|
  puts client.server_capabilities.inspect
  puts client.server_properties.inspect

  client.disconnect { EventMachine.stop }
end
