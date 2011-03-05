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


      DEFAULT_REPLY_TEXT = "Goodbye".freeze

      attr_reader :id
      attr_reader :queues_cache, :exchanges_cache


      attr_reader :deleted_exchanges
      attr_reader :deleted_queues, :bound_queues, :unbound_queues, :purged_queues


      def initialize(client, id)
        super(client)

        @id              = id
        @queues_cache    = Array.new
        @exchanges_cache = Array.new

        # stores queues that were deleted
        # so that we can run callbacks for them
        # when queue.delete-ok arrives.
        @deleted_queues    = Array.new

        @deleted_exchanges = Array.new
        @purged_queues     = Array.new
        @bound_queues      = Array.new
        @unbound_queues    = Array.new

        channel_max = client.connection.channel_max

        if channel_max != 0 && !(0..channel_max).include?(id)
          raise ChannelOutOfBadError.new(channel_max, id)
        end
      end

      def open(&block)
        @client.send Protocol::Channel::Open.encode(@id, "")
        @client.connection.channels[@id] = self
        self.status = :opening
        self.callbacks[:open] = block
      end

      def close(reply_code = 200, reply_text = DEFAULT_REPLY_TEXT, class_id = 0, method_id = 0, &block)
        @client.send Protocol::Channel::Close.encode(@id, reply_code, reply_text, class_id, method_id)
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
        channels.delete(channel)

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
