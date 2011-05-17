# encoding: utf-8

require "amq/client/entity"
require "amq/client/server_named_entity"

module AMQ
  module Client
    class Exchange


      include Entity
      include ServerNamedEntity
      extend ProtocolMethodHandlers

      TYPES = [:fanout, :direct, :topic, :headers].freeze

      class IncompatibleExchangeTypeError < StandardError
        def initialize(types, given)
          super("#{given.inspect} exchange type is unknown. Standard types are #{TYPES.inspect}, custom exchange types must begin with x-, for example: x-recent-history")
        end
      end


      #
      # API
      #

      # Channel this exchange belongs to.
      attr_reader :channel

      # Exchange name. May be server-generated or assigned directly.
      attr_reader :name

      # @return [Symbol] One of :direct, :fanout, :topic, :headers
      attr_reader :type

      def initialize(client, channel, name, type = :fanout)
        if !(TYPES.include?(type.to_sym) || type.to_s =~ /^x-.+/i)
          raise IncompatibleExchangeTypeError.new(TYPES, type)
        end

        @client  = client
        @channel = channel
        @name    = name
        @type    = type

        # register pre-declared exchanges
        if @name == AMQ::Protocol::EMPTY_STRING || @name =~ /^amq\.(fanout|topic)/
          @channel.register_exchange(self)
        end

        super(client)
      end


      def fanout?
        @type == :fanout
      end

      def direct?
        @type == :direct
      end

      def topic?
        @type == :topic
      end



      def declare(passive = false, durable = false, auto_delete = false, nowait = false, arguments = nil, &block)
        @client.send(Protocol::Exchange::Declare.encode(@channel.id, @name, @type.to_s, passive, durable, auto_delete, false, nowait, arguments))

        unless nowait
          self.define_callback(:declare, &block)
          @channel.exchanges_awaiting_declare_ok.push(self)
        end

        self
      end


      def delete(if_unused = false, nowait = false, &block)
        @client.send(Protocol::Exchange::Delete.encode(@channel.id, @name, if_unused, nowait))

        unless nowait
          self.define_callback(:delete, &block)

          # TODO: delete itself from exchanges cache
          @channel.exchanges_awaiting_delete_ok.push(self)
        end

        self
      end # delete(if_unused = false, nowait = false)


      def publish(payload, routing_key = AMQ::Protocol::EMPTY_STRING, user_headers = {}, mandatory = false, immediate = false, frame_size = nil, &block)
        headers = { :priority => 0, :delivery_mode => 2, :content_type => "application/octet-stream" }.merge(user_headers)
        @client.send_frameset(Protocol::Basic::Publish.encode(@channel.id, payload, headers, @name, routing_key, mandatory, immediate, (frame_size || @client.connection.frame_max)))

        block.call if block

        self
      end


      def on_return(&block)
        self.redefine_callback(:return, &block)

        self
      end # on_return(&block)




      def handle_declare_ok(method)
        @name = method.exchange if self.anonymous?
        @channel.register_exchange(self)

        self.exec_callback_once_yielding_self(:declare, method)
      end

      def handle_delete_ok(method)
        self.exec_callback_once(:delete, method)
      end # handle_delete_ok(method)



      # === Handlers ===
      # Get the first exchange which didn't receive Exchange.Declare-Ok yet and run its declare callback.
      # The cache includes only exchanges with {nowait: false}.
      self.handle(Protocol::Exchange::DeclareOk) do |client, frame|
        method = frame.decode_payload

        # We should have cache API, so it'll be easy to change caching behaviour easily.
        # So in the amq-client we don't want to cache more than just the last instance per each channel,
        # whereas more opinionated clients might want to have every single instance in the cache,
        # so they can iterate over it etc.
        channel = client.connection.channels[frame.channel]
        exchange = channel.exchanges_awaiting_declare_ok.shift

        exchange.handle_declare_ok(method)
      end # handle


      self.handle(Protocol::Exchange::DeleteOk) do |client, frame|
        channel  = client.connection.channels[frame.channel]
        exchange = channel.exchanges_awaiting_delete_ok.shift
        exchange.handle_delete_ok(frame.decode_payload)
      end # handle


      self.handle(Protocol::Basic::Return) do |client, frame, content_frames|
        channel  = client.connection.channels[frame.channel]
        method   = frame.decode_payload
        exchange = channel.find_exchange(method.exchange)

        header   = content_frames.shift
        body     = content_frames.map { |frame| frame.payload }.join

        exchange.exec_callback(:return, method, header, body)
      end

    end # Exchange
  end # Client
end # AMQ
