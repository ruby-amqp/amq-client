# encoding: utf-8

module AMQ
  module Client
    class Queue < Entity
      def initialize(adapter, name, default_channel, options = nil)
        @name, @options = name, options
        super(adapter)
      end

      def declare(channel = @default_channel, &block)
        data = Protocol::Queue::Declare.encode(channel, @name, passive, durable, exclusive, auto_delete, arguments)
        @adapter.send(data)
        self.callbacks[:declare] = block
        self
      end

      def bind(exchange, channel = @default_channel, &block)
        data = Protocol::Queue::Bind.encode(channel, @name, exchange, routing_key, arguments)
        @adapter.send(data)
        self.callbacks[:bind] = block
        self
      end

      # Basic.Consume
      # This is a bit tricky, how to route the message to responding Queue instance? Well, we know the exchange, so we can do exchange.queues.each ...
      # ???? Is this really un-opinionated? AMQP specifies it as BASIC.Consume, not Queue.Consume and this is supposed to be no more than just AMQP assembler for Ruby. On the other hand it's linked with the queue object.
      def consume(&block)
        self.callbacks[:consume] = block
      end
    end

    # === Handlers ===
    # Get the first queue which didn't receive Queue.Declare-Ok yet and run its declare callback. The cache includes only queues with {nowait: false}.
    self.handle(Protocol::Queue::DeclareOk) do |client, frame|
      queue = client.cache[AMQ::Protocol::Queue::DeclareOk].shift
      queue.callback(:declare, frame.queue_name, frame.consumer_count, frame.messages_count)
    end

    self.handle(Protocol::Queue::BindOk) do |client, frame|

    end
  end
end
