require "amq/client/async/callbacks"

module AMQ
  module Client
    class Consumer

      #
      # Behaviors
      #

      include Async::Callbacks
      extend Async::ProtocolMethodHandlers



      #
      # API
      #

      attr_reader :channel
      attr_reader :queue
      attr_reader :consumer_tag
      attr_reader :arguments

      def initialize(channel, queue, consumer_tag, exclusive, no_ack, arguments, no_local, &block)
        @callbacks    = Hash.new

        @channel      = channel            || raise(ArgumentError, "channel is nil")
        @connection   = channel.connection || raise(ArgumentError, "connection is nil")
        @queue        = queue        || raise(ArgumentError, "queue is nil")
        @consumer_tag = consumer_tag
        @exclusive    = exclusive
        @no_ack       = no_ack
        @arguments    = arguments

        @no_local     = no_local

        self.register_with_channel
        self.register_with_queue
      end # initialize


      def exclusive?
        !!@exclusive
      end # exclusive?



      def consume(nowait = false, &block)
        @connection.send_frame(Protocol::Basic::Consume.encode(@channel.id, @queue.name, @consumer_tag, @no_local, @no_ack, @exclusive, nowait, @arguments))
        self.redefine_callback(:consume, &block)

        @channel.consumers_awaiting_consume_ok.push(self)

        self
      end # consume(nowait = false, &block)

      # Used by automatic recovery code.
      # @api plugin
      def resubscribe(&block)
        @connection.send_frame(Protocol::Basic::Consume.encode(@channel.id, @queue.name, @consumer_tag, @no_local, @no_ack, @exclusive, block.nil?, @arguments))
        self.redefine_callback(:consume, &block) if block

        self
      end # resubscribe(&block)


      def cancel(nowait = false, &block)
        @connection.send_frame(Protocol::Basic::Cancel.encode(@channel.id, @consumer_tag, nowait))
        self.clear_callbacks(:delivery)
        self.clear_callbacks(:consume)

        if !nowait
          self.redefine_callback(:cancel, &block)
          @channel.consumers_awaiting_cancel_ok.push(self)
        end

        self
      end # cancel(nowait = false, &block)



      def on_delivery(&block)
        self.append_callback(:delivery, &block)

        self
      end # on_delivery(&block)


        # @group Acknowledging & Rejecting Messages

        # Acknowledge a delivery tag.
        # @return [Consumer]  self
        #
        # @api public
        # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.13.)
        def acknowledge(delivery_tag)
          @channel.acknowledge(delivery_tag)

          self
        end # acknowledge(delivery_tag)

        #
        # @return [Consumer]  self
        #
        # @api public
        # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.14.)
        def reject(delivery_tag, requeue = true)
          @channel.reject(delivery_tag, requeue)

          self
        end # reject(delivery_tag, requeue = true)

        # @endgroup



      #
      # Implementation
      #

      def handle_delivery(basic_deliver, metadata, payload)
        self.exec_callback(:delivery, basic_deliver, metadata, payload)
      end # handle_delivery(basic_deliver, metadata, payload)

      def handle_consume_ok(consume_ok)
        self.exec_callback_once(:consume, consume_ok)
      end # handle_consume_ok(consume_ok)

      def handle_cancel_ok(cancel_ok)
        @consumer_tag = nil

        # detach from object graph so that this object will be garbage-collected
        @queue        = nil
        @channel      = nil
        @connection   = nil

        self.exec_callback_once(:cancel, cancel_ok)
      end # handle_cancel_ok(method)



      self.handle(Protocol::Basic::ConsumeOk) do |connection, frame|
        channel  = connection.channels[frame.channel]
        consumer = channel.consumers_awaiting_consume_ok.shift

        consumer.handle_consume_ok(frame.decode_payload)
      end


      self.handle(Protocol::Basic::CancelOk) do |connection, frame|
        channel  = connection.channels[frame.channel]
        consumer = channel.consumers_awaiting_cancel_ok.shift

        consumer.handle_consume_ok(frame.decode_payload)
      end


      self.handle(Protocol::Basic::Deliver) do |connection, method_frame, content_frames|
        channel       = connection.channels[method_frame.channel]
        basic_deliver = method_frame.decode_payload
        consumer      = channel.consumers[basic_deliver.consumer_tag]

        metadata = content_frames.shift
        payload  = content_frames.map { |frame| frame.payload }.join

        consumer.handle_delivery(basic_deliver, metadata, payload)
      end


      protected

      def register_with_channel
        @channel.consumers[@consumer_tag] = self
      end # register_with_channel

      def register_with_queue
        @queue.consumers[@consumer_tag]   = self
      end # register_with_queue

    end # Consumer
  end # Client
end # AMQ
