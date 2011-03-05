# encoding: utf-8

require "amq/client/entity"
require "amq/client/adapter"
require "amq/client/mixins/anonymous_entity"

module AMQ
  module Client
    class Queue < Entity

      #
      # Behaviors
      #

      include AnonymousEntityMixin


      #
      # API
      #

      attr_reader :name

      def initialize(client, channel, name)
        super(client)

        @name    = name
        @channel = channel
      end


      def declare(passive = false, durable = false, exclusive = false, auto_delete = false, nowait = false, arguments = nil, &block)
        @client.send(Protocol::Queue::Declare.encode(@channel.id, @name, passive, durable, exclusive, auto_delete, nowait, arguments))

        self.callbacks[:declare] = block
        self.execute_callback(:declare) if nowait


        @channel.queues_awaiting_declare_ok << self

        if @client.sync?
          @client.read_until_receives(Protocol::Queue::DeclareOk) unless nowait
        end

        self
      end


      def delete(if_unused = false, if_empty = false, nowait = false, &block)
        @client.send(Protocol::Queue::Delete.encode(@channel.id, @name, if_unused, if_empty, nowait))

        self.callbacks[:delete] = block

        # TODO: delete itself from queues cache
        @channel.queues_awaiting_delete_ok.push(self)

        self
      end # delete(channel, queue, if_unused, if_empty, nowait, &block)



      def bind(exchange, routing_key = AMQ::Protocol::EMPTY_STRING, nowait = false, arguments = nil, &block)
        exchange_name = if exchange.respond_to?(:name)
                          exchange.name
                        else

                          exchange
                        end

        @client.send(Protocol::Queue::Bind.encode(@channel.id, @name, exchange_name, routing_key, nowait, arguments))
        self.callbacks[:bind] = block

        # TODO: handle channel & connection-level exceptions
        @channel.queues_awaiting_bind_ok.push(self)

        self
      end



      def unbind(exchange, routing_key = AMQ::Protocol::EMPTY_STRING, arguments = nil, &block)
        exchange_name = if exchange.respond_to?(:name)
                          exchange.name
                        else

                          exchange
                        end

        @client.send(Protocol::Queue::Unbind.encode(@channel.id, @name, exchange_name, routing_key, arguments))
        self.callbacks[:unbind] = block

        # TODO: handle channel & connection-level exceptions
        @channel.unqueues_awaiting_bind_ok.push(self)

        self
      end




      # Basic.Consume
      def consume(no_local = false, no_ack = false, exclusive = false, nowait = false, arguments = nil, &block)
        raise RuntimeError.new("This instance is already being consumed! Create another one using #dup.") if @consumer_tag

        @consumer_tag                    = "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
        @client.send(Protocol::Basic::Consume.encode(@channel.id, @name, @consumer_tag, false, false, false, false, nil))

        @client.consumers[@consumer_tag] = self

        # TODO: consider supporting multiple consumers in the same Ruby process here.
        self.callbacks[:consume]         = block

        @channel.queues_awaiting_consume_ok.push(self)

        self
      end


      def purge(nowait = false, &block)
        self.callbacks[:purge] = block
        @client.send(Protocol::Queue::Purge.encode(@channel.id, @name, nowait))

        # TODO: handle channel & connection-level exceptions
        @channel.queues_awaiting_purge_ok.push(self)

        self
      end # purge(nowait = false, &block)




      def handle_declare_ok(method)
        @name = method.queue if self.anonymous?

        self.exec_callback(:declare, method.queue, method.consumer_count, method.message_count)
      end

      def handle_delete_ok(method)
        self.exec_callback(:delete, method.message_count)
      end # handle_delete_ok(method)

      def handle_consume_ok(method)
        self.exec_callback(:consume, method.consumer_tag)
      end # handle_consume_ok(method)

      def handle_purge_ok(method)
        self.exec_callback(:purge, method.message_count)
      end # handle_purge_ok(method)

      def handle_bind_ok(method)
        self.exec_callback(:bind)
      end # handle_bind_ok(method)

      def handle_unbind_ok(method)
        self.exec_callback(:unbind)
      end # handle_unbind_ok(method)



      # === Handlers ===
      # Get the first queue which didn't receive Queue.Declare-Ok yet and run its declare callback. The cache includes only queues with {nowait: false}.
      self.handle(Protocol::Queue::DeclareOk) do |client, frame|
        method = frame.decode_payload

        # We should have cache API, so it'll be easy to change caching behaviour easily. So in the amq-client we don't want to cache more than just the last instance per each channel, whereas more opinionated clients might want to have every single instance in the cache, so they can iterate over it etc.
        channel = client.connection.channels[frame.channel]
        queue = channel.queues_awaiting_declare_ok.shift

        queue.handle_declare_ok(method)
      end


      self.handle(Protocol::Queue::DeleteOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_delete_ok.shift
        queue.handle_delete_ok(frame.decode_payload)
      end


      self.handle(Protocol::Queue::BindOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_bind_ok.shift

        queue.handle_bind_ok(frame.decode_payload)
      end


      self.handle(Protocol::Queue::UnbindOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.unqueues_awaiting_bind_ok.shift

        queue.handle_unbind_ok(frame.decode_payload)
      end


      self.handle(Protocol::Basic::ConsumeOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_consume_ok.shift

        queue.handle_consume_ok(frame.decode_payload)
      end

      # Basic.Deliver
      self.handle(Protocol::Basic::Deliver) do |client, frame, header, *body|
        method = frame.decode_payload
        queue  = client.consumers[method.consumer_tag]
        body   = body.reduce("") { |buffer, frame| buffer += frame.body }
        queue.exec_callback(:consume, body)
      end


      self.handle(Protocol::Queue::PurgeOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_purge_ok.shift

        queue.handle_purge_ok(frame.decode_payload)
      end

    end # Queue
  end # Client
end # AMQ
