# encoding: utf-8

require "amq/client/entity"
require "amq/client/adapter"

module AMQ
  module Client
    class Channel < Entity

      #
      # API
      #


      class ChannelOutOfBadError < StandardError # TODO: inherit from some AMQP error class defined in amq-protocol or use it straight away.
        def initialize(max, given)
          super("Channel max is #{max}, #{given} given.")
        end
      end


      DEFAULT_REPLY_TEXT = "Goodbye".freeze

      attr_reader :id

      attr_reader :exchanges_awaiting_declare_ok, :exchanges_awaiting_delete_ok
      attr_reader :queues_awaiting_declare_ok, :queues_awaiting_delete_ok, :queues_awaiting_bind_ok, :queues_awaiting_unbind_ok, :queues_awaiting_purge_ok, :queues_awaiting_consume_ok, :queues_awaiting_cancel_ok, :queues_awaiting_get_response


      def initialize(client, id)
        super(client)

        @id        = id
        @exchanges = Hash.new
        @queues    = Hash.new

        reset_state!

        # 65536 is here for cases when channel is opened without passing a callback in,
        # otherwise channel_mix would be nil and it causes a lot of needless headaches. 
        # lets just have this default. MK.
        channel_max = client.connection.channel_max || 65536

        if channel_max != 0 && !(0..channel_max).include?(id)
          raise ChannelOutOfBadError.new(channel_max, id)
        end
      end

      # @return  [Array<Queue>]   Collection of queues that were declared on this channel.
      def queues
        @queues.values
      end

      # @return  [Array<Exchange>]  Collection of exchanges that were declared on this channel.
      def exchanges
        @exchanges.values
      end


      # AMQP connection this channel belongs to.
      #
      # @return [AMQ::Client::Connection] Connection this channel belongs to.
      def connection
        @client.connection
      end # connection

      # Opens AMQP channel.
      #
      # @api public
      def open(&block)
        @client.send Protocol::Channel::Open.encode(@id, AMQ::Protocol::EMPTY_STRING)
        @client.connection.channels[@id] = self
        self.status = :opening
        self.callbacks[:open] = block
      end

      # Closes AMQP channel.
      #
      # @api public
      def close(reply_code = 200, reply_text = DEFAULT_REPLY_TEXT, class_id = 0, method_id = 0, &block)
        @client.send Protocol::Channel::Close.encode(@id, reply_code, reply_text, class_id, method_id)
        self.callbacks[:close] = block
      end


      # Acknowledge one or all messages on the channel.
      #
      # @api public
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.13.)
      def acknowledge(delivery_tag, multiple = false)
        @client.send(Protocol::Basic::Ack.encode(self.id, delivery_tag, multiple))

        self
      end # acknowledge(delivery_tag, multiple = false)

      # Reject a message with given delivery tag.
      #
      # @api public
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.14.)
      def reject(delivery_tag, requeue = true)
        @client.send(Protocol::Basic::Reject.encode(self.id, delivery_tag, requeue))
      end # reject(delivery_tag, requeue = true)

      # Requests a specific quality of service. The QoS can be specified for the current channel
      # or for all channels on the connection.
      #
      # @note RabbitMQ as of 2.3.1 does not support prefetch_size.
      # @api public
      def qos(prefetch_size = 0, prefetch_count = 32, global = false, &block)
        @client.send Protocol::Basic::Qos.encode(@id, prefetch_size, prefetch_count, global)

        self.callbacks[:qos] = block
        self.connection.channels_awaiting_qos_ok.push(self)
      end # qos(prefetch_size = 4096, prefetch_count = 32, global = false, &block)

      # Notifies AMQ broker that consumer has recovered and unacknowledged messages need
      # to be redelivered.
      #
      # @return [Queue]  self
      #
      # @note RabbitMQ as of 2.3.1 does not support basic.recover with requeue = false.
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.8.3.16.)
      def recover(requeue = true, &block)
        @client.send(Protocol::Basic::Recover.encode(@id, requeue))

        self.callbacks[:recover] = block
        self.connection.channels_awaiting_recover_ok.push(self)

        self
      end # recover(requeue = false, &block)

      # Asks the peer to pause or restart the flow of content data sent to a consumer.
      # This is a simple flow­control mechanism that a peer can use to avoid overflowing its
      # queues or otherwise finding itself receiving more messages than it can process. Note that
      # this method is not intended for window control. It does not affect contents returned to
      # Queue#get callers.
      #
      # @param [Boolean] Desired flow state.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.5.2.3.)
      # @api public
      def flow(active = false, &block)
        @client.send Protocol::Channel::Flow.encode(@id, active)

        self.callbacks[:flow] = block
        self.connection.channels_awaiting_flow_ok.push(self)
      end # flow(active = false, &block)


      # Sets the channel to use standard transactions. One must use this method at least
      # once on a channel before using #tx_tommit or tx_rollback methods.
      #
      # @api public
      def tx_select(&block)
        @client.send Protocol::Tx::Select.encode(@id)

        self.callbacks[:tx_select] = block
        self.connection.channels_awaiting_tx_select_ok.push(self)
      end # tx_select(&block)

      # Commits AMQP transaction.
      #
      # @api public
      def tx_commit(&block)
        @client.send Protocol::Tx::Commit.encode(@id)

        self.callbacks[:tx_commit] = block
        self.connection.channels_awaiting_tx_commit_ok.push(self)
      end # tx_commit(&block)

      # Rolls AMQP transaction back.
      #
      # @api public
      def tx_rollback(&block)
        @client.send Protocol::Tx::Rollback.encode(@id)

        self.callbacks[:tx_rollback] = block
        self.connection.channels_awaiting_tx_rollback_ok.push(self)
      end # tx_rollback(&block)

      # @return [Boolean]  True if flow in this channel is active (messages will be delivered to consumers that use this channel).
      #
      # @api public
      def flow_is_active?
        @flow_is_active
      end # flow_is_active?



      #
      # Implementation
      #

      def register_exchange(exchange)
        raise ArgumentError, "argument is nil!" if exchange.nil?

        @exchanges[exchange.name] = exchange
      end # register_exchange(exchange)

      def find_exchange(name)
        @exchanges[name]
      end

      def register_queue(queue)
        raise ArgumentError, "argument is nil!" if queue.nil?

        @queues[queue.name] = queue
      end # register_queue(queue)

      def find_queue(name)
        @queues[name]
      end


      def reset_state!
        @flow_is_active                = true

        @queues_awaiting_declare_ok    = Array.new
        @exchanges_awaiting_declare_ok = Array.new

        @queues_awaiting_delete_ok     = Array.new

        @exchanges_awaiting_delete_ok  = Array.new
        @queues_awaiting_purge_ok      = Array.new
        @queues_awaiting_bind_ok       = Array.new
        @queues_awaiting_unbind_ok     = Array.new
        @queues_awaiting_consume_ok    = Array.new
        @queues_awaiting_cancel_ok     = Array.new

        @queues_awaiting_get_response  = Array.new
      end # reset_state!


      def on_connection_interruption
        self.reset_state!
      end # on_connection_interruption

      def handle_open_ok
        self.status = :opened
        self.exec_callback_once(:open)
      end

      def handle_close_ok
        self.status = :closed
        self.exec_callback_once(:close)
      end

      def handle_close(method)
        raise method.inspect
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

      self.handle Protocol::Basic::QosOk do |client, frame|
        channel  = client.connection.channels_awaiting_qos_ok.shift
        channel.exec_callback(:qos)
      end

      self.handle(Protocol::Basic::RecoverOk) do |client, frame|
        client.connection.channels[frame.channel].exec_callback(:recover)
      end

      self.handle Protocol::Channel::FlowOk do |client, frame|
        channel         = client.connection.channels_awaiting_flow_ok.shift
        flow_activity   = frame.decode_payload.active
        @flow_is_active = flow_activity
        channel.exec_callback(:flow, flow_activity)
      end

      self.handle Protocol::Tx::SelectOk do |client, frame|
        channel  = client.connection.channels_awaiting_tx_select_ok.shift
        channel.exec_callback(:tx_select)
      end

      self.handle Protocol::Tx::CommitOk do |client, frame|
        channel  = client.connection.channels_awaiting_tx_commit_ok.shift
        channel.exec_callback(:tx_commit)
      end

      self.handle Protocol::Tx::RollbackOk do |client, frame|
        channel  = client.connection.channels_awaiting_tx_rollback_ok.shift
        channel.exec_callback(:tx_rollback)
      end
    end # Channel
  end # Client
end # AMQ
