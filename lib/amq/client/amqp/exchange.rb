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

      attr_reader :name, :type
      def initialize(client, name, type = :fanout, default_channel = nil)
        @name, @type, @default_channel = name, type, default_channel

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

      def declare(channel = @default_channel, passive = false, durable = false, exclusive = false, auto_delete = false, nowait = false, arguments = nil, &block)
        data = Protocol::Exchange::Declare.encode(channel.id, @name, @type.to_s, passive, durable, exclusive, auto_delete, nowait, arguments)
        @client.send(data)

        self.callbacks[:declare] = block

        self.execute_callback(:declare) if nowait

        channel ||= client.get_random_channel

        channel.exchanges_cache << self

        if @client.sync?
          unless nowait
            @client.read_until_receives(Protocol::Exchange::DeclareOk)
          end
        end

        self
      end

      def handle_declare_ok(method)
        @name = method.exchange if self.anonymous?
        self.exec_callback(:declare, method)
      end

      # === Handlers ===
      # Get the first exchange which didn't receive Exchange.Declare-Ok yet and run its declare callback. The cache includes only exchanges with {nowait: false}.
      self.handle(Protocol::Exchange::DeclareOk) do |client, frame|
        method = frame.decode_payload

        # We should have cache API, so it'll be easy to change caching behaviour easily. So in the amq-client we don't want to cache more than just the last instance per each channel, whereas more opinionated clients might want to have every single instance in the cache, so they can iterate over it etc.
        channel = client.connection.channels[frame.channel]
        exchange = channel.exchanges_cache.shift

        exchange.handle_declare_ok(method)
      end
    end
  end
end
