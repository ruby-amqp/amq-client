#!/usr/bin/env ruby
# encoding: utf-8

__dir = File.dirname(File.expand_path(__FILE__))
require File.join(__dir, "..", "example_helper")

amq_client_example "Handling a channel-level exception" do |connection|
  channel = AMQ::Client::Channel.new(connection, 1)
  channel.open do
    puts "Channel #{channel.id} is now open!"

    channel.on_error do |ch, close|
      puts "Handling a channel-level exception: #{close.reply_text}"
    end

    EventMachine.add_timer(0.4) do
      # these two definitions result in a race condition. For sake of this example,
      # however, it does not matter. Whatever definition succeeds first, 2nd one will
      # cause a channel-level exception (because attributes are not identical)
      AMQ::Client::Queue.new(connection, channel, "amqpgem.examples.channel_exception").declare(false, false, false, true) do |queue|
        puts "#{queue.name} is ready to go"
      end

      AMQ::Client::Queue.new(connection, channel, "amqpgem.examples.channel_exception").declare(false, true, false, false) do |queue|
        puts "#{queue.name} is ready to go"
      end
    end
  end


  show_stopper = Proc.new do
    $stdout.puts "Stopping..."
    connection.close { EventMachine.stop }
  end

  Signal.trap "INT", show_stopper
  EM.add_timer(2, show_stopper)
end
