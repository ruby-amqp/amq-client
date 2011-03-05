# encoding: utf-8

require "amq/client/entity"
require "amq/client/mixins/anonymous_entity"

module AMQ
  module Client
    class Exchange < Entity
      include AnonymousEntityMixin

      TYPES = [:fanout, :direct, :topic].freeze

      class IncompatibleExchangeTypeError < StandardError
        def initialize(types, given)
          super("Exchange types are #{TYPES.inspect}, #{given.inspect} given.")
        end
      end


      #
      # API
      #


      attr_reader :name, :type

      def initialize(client, channel, name, type = :fanout)
        @client  = client
        @channel = channel
        @name    = name
        @type    = type

        unless TYPES.include?(type)
          raise IncompatibleExchangeTypeError.new(TYPES, type)
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



      def declare(passive = false, durable = false, exclusive = false, auto_delete = false, nowait = false, arguments = nil, &block)
        data = Protocol::Exchange::Declare.encode(@channel.id, @name, @type.to_s, passive, durable, auto_delete, false, nowait, arguments)
        @client.send(data)

        self.callbacks[:declare] = block

        @channel.exchanges_cache << self

        if @client.sync?
          unless nowait
            @client.read_until_receives(Protocol::Exchange::DeclareOk)
          end
        end

        self
      end


      def delete(if_unused = false, nowait = false, &block)
        @client.send(Protocol::Exchange::Delete.encode(@channel.id, @name, if_unused, nowait))

        self.callbacks[:delete] = block

        # TODO: delete itself from exchanges cache
        @channel.deleted_exchanges.push(self)

        self
      end # delete(if_unused = false, nowait = false)


      def publish(payload, routing_key = AMQ::Protocol::EMPTY_STRING, user_headers = { :priority => 0, :delivery_mode => 2, :content_type => "application/octet-stream" }, mandatory = false, immediate = false, frame_size = nil)
        @client.send_frameset(Protocol::Basic::Publish.encode(@channel.id, payload, user_headers, @name, routing_key, mandatory, immediate, (frame_size || @client.connection.frame_max)))

        self
      end





      def handle_declare_ok(method)
        @name = method.exchange if self.anonymous?
        self.exec_callback(:declare, method)
      end

      def handle_delete_ok(method)
        self.exec_callback(:delete)
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
        exchange = channel.exchanges_cache.shift

        exchange.handle_declare_ok(method)
      end # handle


      self.handle(Protocol::Exchange::DeleteOk) do |client, frame|
        channel  = client.connection.channels[frame.channel]
        exchange = channel.deleted_exchanges.shift
        exchange.handle_delete_ok(frame.decode_payload)
      end # handle

    end # Exchange
  end # Client
end # AMQ
