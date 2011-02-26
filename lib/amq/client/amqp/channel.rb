# encoding: utf-8

require "amq/client/entity"
require "amq/client/adapter"

module AMQ
  module Client
    class Channel < Entity
      class ChannelOutOfBadError < StandardError # TODO: inherit from some AMQP error class defined in amq-protocol or use it straight away.
        def initialize(max, given)
          super("Channel max is #{max}, #{given} given.")
        end
      end

      attr_reader :id
      attr_reader :queues_cache, :exchanges_cache

      def initialize(client, id)
        super(client)
        @id = id
        @queues_cache, @exchanges_cache = Array.new, Array.new

        channel_max = client.connection.channel_max
        if channel_max != 0 && ! (0..channel_max).include?(id)
          raise ChannelOutOfBadError.new(channel_max, id)
        end
      end

      def open(&block)
        @client.send Protocol::Channel::Open.encode(@id, "")
        @client.connection.channels[@id] = self
        self.status = :opening
        self.callbacks[:open] = block
      end

      def close(&block)
        @client.send Protocol::Channel::Close.encode(1)
        @client.connection.channels.delete(@id)
        self.callbacks[:close] = block
      end

      def handle_open_ok
        self.status = :opened
        self.exec_callback(:open)
      end

      def handle_close_ok
        self.status = :closed
        self.exec_callback(:close)
      end

      def handle_close(method)
        p method
      end

      # === Handlers ===

      self.handle(Protocol::Channel::OpenOk) do |client, frame|
        channels = client.connection.channels
        channel = channels[frame.channel]
        channel.handle_open_ok
      end

      self.handle(Protocol::Channel::CloseOk) do |client, frame|
        method   = frame.decode_payload
        channels = client.connection.channels
        channel  = channels[frame.channel]
        channel.handle_close_ok
      end

      self.handle(Protocol::Channel::Close) do |client, frame|
        method   = frame.decode_payload
        channels = client.connection.channels
        channel  = channels[frame.channel]
        channel.handle_close(method)
      end
    end
  end
end
