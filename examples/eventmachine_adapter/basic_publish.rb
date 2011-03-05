#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "example_helper")


if RUBY_VERSION.to_s =~ /^1.9/
  puts "Encoding.default_internal was #{Encoding.default_internal || 'not set'}, switching to UTF8"
  Encoding.default_internal = Encoding::UTF_8

  puts "Encoding.default_external was #{Encoding.default_internal || 'not set'}, switching to UTF8"
  Encoding.default_external = Encoding::UTF_8
end


EM.run do
  AMQ::Client::EventMachineClient.connect(:port => 5672, :vhost => "/amq_client_testbed") do |client|
    begin
      puts "AMQP connection is open: #{client.connection.server_properties.inspect}"

      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        puts "Channel #{channel.id} is now open!"
      end

      exchange = AMQ::Client::Exchange.new(client, channel, "amqclient.adapters.em.exchange1", :fanout)
      exchange.declare do
        100.times do
          print "."
          # exchange.publish("à bientôt!")
          exchange.publish("See you soon!")
        end

        $stdout.flush
      end

      show_stopper = Proc.new {
        client.disconnect do
          puts
          puts "AMQP connection is now properly closed"
          EM.stop
        end
      }

      Signal.trap "INT",  show_stopper
      Signal.trap "TERM", show_stopper
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
