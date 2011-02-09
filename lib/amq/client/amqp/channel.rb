# encoding: utf-8

require "amq/client/entity"

module AMQ
  module Client
    class Channel < Entity
      def initialize(client, id)
        super(client)
        @id = id
      end

      def open(&block)
        @client.send Protocol::Channel::Open.encode(@id, "")
        @client.connection.channels[@id] = self
        self.callbacks[:open] = block
      end

      def close(&block)
        @client.send Protocol::Channel::Close.encode(1)
        @client.connection.channels.delete(@id)
        self.callbacks[:close] = block
      end

      def handle_open_ok
        @opened = true
        self.exec_callback(:open)
      end

      def handle_close_ok
        @opened = false
        self.exec_callback(:close)
      end

      # === Handlers ===
      self.handle(Protocol::Channel::OpenOk) do |client, method|
        p method
        p method.channel_id
        p client.connection.channels

        channels = client.connection.channels
        channel = channels[method.channel_id]
        channel.handle_open_ok
      end

      self.handle(Protocol::Channel::CloseOk) do |client, method|
        channels = client.connection.channels
        channel = channels[method.channel_id]
        channel.handle_close_ok
      end
    end
  end
end
