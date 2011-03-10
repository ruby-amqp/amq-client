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

      def initialize(client, channel, name = AMQ::Protocol::EMPTY_STRING)
        super(client)

        @name    = name
        @channel = channel
      end

      def durable?
        @durable
      end # durable?

      def exclusive?
        @exclusive
      end # exclusive?

      def auto_delete?
        @auto_delete
      end # auto_delete?



      def declare(passive = false, durable = false, exclusive = false, auto_delete = false, nowait = false, arguments = nil, &block)
        @durable     = durable
        @exclusive   = exclusive
        @auto_delete = auto_delete

        nowait = true unless block
        @client.send(Protocol::Queue::Declare.encode(@channel.id, @name, passive, durable, exclusive, auto_delete, nowait, arguments))

        if !nowait
          self.callbacks[:declare] = block
          @channel.queues_awaiting_declare_ok.push(self)
        end

        if @client.sync?
          @client.read_until_receives(Protocol::Queue::DeclareOk) unless nowait
        end

        self
      end


      def delete(if_unused = false, if_empty = false, nowait = false, &block)
        nowait = true unless block
        @client.send(Protocol::Queue::Delete.encode(@channel.id, @name, if_unused, if_empty, nowait))

        if !nowait
          self.callbacks[:delete] = block

          # TODO: delete itself from queues cache
          @channel.queues_awaiting_delete_ok.push(self)
        end

        self
      end # delete(channel, queue, if_unused, if_empty, nowait, &block)



      def bind(exchange, routing_key = AMQ::Protocol::EMPTY_STRING, nowait = false, arguments = nil, &block)
        nowait = true unless block
        exchange_name = if exchange.respond_to?(:name)
                          exchange.name
                        else

                          exchange
                        end

        @client.send(Protocol::Queue::Bind.encode(@channel.id, @name, exchange_name, routing_key, nowait, arguments))

        if !nowait
          self.callbacks[:bind] = block

          # TODO: handle channel & connection-level exceptions
          @channel.queues_awaiting_bind_ok.push(self)
        end

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
        @channel.queues_awaiting_unbind_ok.push(self)

        self
      end



      # Basic.Consume
      def consume(no_ack = false, exclusive = false, nowait = false, no_local = false, arguments = nil, &block)
        raise RuntimeError.new("This instance is already being consumed! Create another one using #dup.") if @consumer_tag

        nowait        = true unless block
        @consumer_tag = "#{name}-#{Time.now.to_i * 1000}-#{Kernel.rand(999_999_999_999)}"
        @client.send(Protocol::Basic::Consume.encode(@channel.id, @name, @consumer_tag, no_local, no_ack, exclusive, nowait, arguments))

        @client.consumers[@consumer_tag] = self

        if !nowait
          self.callbacks[:consume]         = block

          @channel.queues_awaiting_consume_ok.push(self)
        end

        self
      end



      def get(no_ack = false, &block)
        @client.send(Protocol::Basic::Get.encode(@channel.id, @name, no_ack))

        self.callbacks[:get] = block
        @channel.queues_awaiting_get_response.push(self)

        self
      end # get(no_ack = false, &block)



      def cancel(nowait = false, &block)
        @client.send(Protocol::Basic::Cancel.encode(@channel.id, @consumer_tag, nowait))

        if !nowait
          self.callbacks[:consume] = block

          @channel.queues_awaiting_cancel_ok.push(self)
        else
          @consumer_tag            = nil
        end
      end # cancel(&block)



      def purge(nowait = false, &block)
        nowait        = true unless block
        @client.send(Protocol::Queue::Purge.encode(@channel.id, @name, nowait))

        if !nowait
          self.callbacks[:purge] = block
          # TODO: handle channel & connection-level exceptions
          @channel.queues_awaiting_purge_ok.push(self)
        end

        self
      end # purge(nowait = false, &block)

      def acknowledge(delivery_tag, multiple = false)
        @client.send(Protocol::Basic::Ack.encode(@channel.id, delivery_tag, multiple))
      end # acknowledge(delivery_tag, multiple = false)

      def reject(delivery_tag, requeue = true)
        @client.send(Protocol::Basic::Reject.encode(@channel.id, delivery_tag, requeue))
      end # reject(delivery_tag, requeue = true)




      def on_delivery(&block)
        self.callbacks[:delivery] = block if block
      end # on_delivery(&block)




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

      def handle_delivery(method, header, payload)
        self.exec_callback(:delivery, header, payload, method.consumer_tag, method.delivery_tag, method.redelivered, method.exchange, method.routing_key)
      end # def handle_delivery

      def handle_cancel_ok(method)
        @consumer_tag            = nil
        self.exec_callback(:cancel, method.consumer_tag)
      end # handle_cancel_ok(method)

      def handle_get_ok(method, header, payload)
        self.exec_callback(:get, header, payload, method.delivery_tag, method.redelivered, method.exchange, method.routing_key, method.message_count)
      end # handle_get_ok(method, header, payload)

      def handle_get_empty(method)
        self.exec_callback(:get)
      end # handle_get_empty(method)



      # === Handlers ===
      # Get the first queue which didn't receive Queue.Declare-Ok yet and run its declare callback.
      # The cache includes only queues with {nowait: false}.
      self.handle(Protocol::Queue::DeclareOk) do |client, frame|
        method  = frame.decode_payload

        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_declare_ok.shift

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
        queue   = channel.queues_awaiting_unbind_ok.shift

        queue.handle_unbind_ok(frame.decode_payload)
      end


      self.handle(Protocol::Basic::ConsumeOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_consume_ok.shift

        queue.handle_consume_ok(frame.decode_payload)
      end


      self.handle(Protocol::Basic::CancelOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_cancel_ok.shift

        queue.handle_consume_ok(frame.decode_payload)
      end


      # Basic.Deliver
      self.handle(Protocol::Basic::Deliver) do |client, method_frame, content_frames|
        method   = method_frame.decode_payload
        queue    = client.consumers[method.consumer_tag]

        header = content_frames.shift
        body   = content_frames.map {|frame| frame.payload }.join
        queue.handle_delivery(method, header, body)
        # TODO: ack if necessary
      end


      self.handle(Protocol::Queue::PurgeOk) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_purge_ok.shift

        queue.handle_purge_ok(frame.decode_payload)
      end


      self.handle(Protocol::Basic::GetOk) do |client, frame, content_frames|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_get_response.shift
        method  = frame.decode_payload

        header  = content_frames.shift
        body    = content_frames.map {|frame| frame.payload }.join

        queue.handle_get_ok(method, header, body)
      end


      self.handle(Protocol::Basic::GetEmpty) do |client, frame|
        channel = client.connection.channels[frame.channel]
        queue   = channel.queues_awaiting_get_response.shift

        queue.handle_get_empty(frame.decode_payload)
      end
    end # Queue
  end # Client
end # AMQ
