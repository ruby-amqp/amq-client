#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")

EM.run do
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
    begin
      puts "AMQP connection is open: #{client.connection.server_properties.inspect}"

      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        puts "Channel #{channel.id} is now open!"
      end


      channel.close do
        puts "Closed channel ##{channel.id}"
        puts
        client.disconnect do
          puts
          puts "AMQP connection is now properly closed"
          EM.stop
        end
      end
    rescue Interrupt
      warn "Manually interrupted, terminating ..."
    rescue Exception => exception
      STDERR.puts "\n\e[1;31m[#{exception.class}] #{exception.message}\e[0m"
      exception.backtrace.each do |line|
        line = "\e[0;36m#{line}\e[0m" if line.match(Regexp::quote(File.basename(__FILE__)))
        STDERR.puts "  - " + line
      end
    end
  end
end
