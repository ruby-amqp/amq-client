# encoding: utf-8

require "amq/client/entity"
require "amq/client/adapter"

module AMQ
  module Client
    class Queue < Entity
      def initialize(client, name, default_channel = nil)
        @name, @default_channel = name, default_channel
        super(client)
      end

      def declare(channel = @default_channel, passive = false, durable = false, exclusive = false, auto_delete = false, arguments = nil, &block)
        data = Protocol::Queue::Declare.encode(channel.id, @name, passive, durable, exclusive, auto_delete, arguments)
        @client.send(data)

        self.callbacks[:declare] = block

        self.execute_callback(:declare) if nowait

        channel ||= client.get_random_channel

        channel.queues_cache << self

        if @client.sync? #&& self.nowait == false
          until @client.receive.is_a?(Protocol::Queue::DeclareOk)
            @client.receive
          end
        end

        self
      end

      def bind(exchange, channel = @default_channel, &block)
        data = Protocol::Queue::Bind.encode(channel, @name, exchange, routing_key, arguments)
        @client.send(data)
        self.callbacks[:bind] = block
        self
      end

      # Basic.Consume
      def consume(&block)
        if @consumer_tag
          raise RuntimeError.new("This instance is already being consumed! Create another one using #dup.")
        end
        @consumer_tag = "random sh1t3"
        client.consumers[@consumer_tag] = self ### WHAT IF there'll be more consume blocks for the same object? Now that's about opinion, but we are NOT building an opinionated API here!!!!
        self.callbacks[:consume] = block
      end

      def dup
        if @name.eql?("")
          raise RuntimeError.new("You can't clone anonymous queue until it receives back the name in Queue.Declare-Ok response. Move the code with #dup to the callback for the #declare method.") # TODO: that's not true in all cases, imagine the user didn't call #declare yet.
        end
        instance = self.dup
        instance.instance_variable_set(:@consumer_tag, nil)
        instance
      end

      # === Handlers ===
      # Get the first queue which didn't receive Queue.Declare-Ok yet and run its declare callback. The cache includes only queues with {nowait: false}.
      self.handle(Protocol::Queue::DeclareOk) do |client, frame|
        method = frame.decode_payload

        # We should have cache API, so it'll be easy to change caching behaviour easily. So in the amq-client we don't want to cache more than just the last instance per each channel, whereas more opinionated clients might want to have every single instance in the cache, so they can iterate over it etc.
        channel = client.connection.channels[frame.channel]
        queue = channel.queues_cache.shift

        queue.exec_callback(:declare, method.queue, method.consumer_count, method.message_count)
      end

      self.handle(Protocol::Queue::BindOk) do |client, frame|
        method = frame.decode_payload
      end

      # Basic.Deliver
      self.handle(Protocol::Basic::Deliver) do |client, frame, header, *body|
        method = frame.decode_payload
        queue  = client.consumers[method.consumer_tag]
        body   = body.reduce("") { |buffer, frame| buffer += frame.body }
        queue.exec_callback(:consume, body)
      end
    end
  end
end
