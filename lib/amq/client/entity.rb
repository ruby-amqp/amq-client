# encoding: utf-8

require "amq/client/callbacks"
require "amq/client/openable"

module AMQ
  module Client
    module RegisterEntityMixin
      # @example Registering Channel implementation
      #  Adapter.register_entity(:channel, Channel)
      #   # ... so then I can do:
      #  channel = client.channel(1)
      #  # instead of:
      #  channel = Channel.new(client, 1)
      def register_entity(name, klass)
        define_method(name) do |*args, &block|
          klass.new(self, *args, &block)
        end # define_method
      end # register_entity
    end # RegisterEntityMixin

    module ProtocolMethodHandlers
      def handle(klass, &block)
        AMQ::Client::HandlersRegistry.register(klass, &block)
      end

      def handlers
        AMQ::Client::HandlersRegistry.handlers
      end
    end # ProtocolMethodHandlers


    # AMQ entities, as implemented by AMQ::Client, have callbacks and can run them
    # when necessary.
    #
    # @note Exchanges and queues implementation is based on this class.
    #
    # @abstract
    module Entity

      #
      # Behaviors
      #

      include Openable
      include Callbacks

      #
      # API
      #

      # @return [Array<#call>]
      attr_reader :callbacks


      def initialize(connection)
        @connection = connection
        # Be careful with default values for #ruby hashes: h = Hash.new(Array.new); h[:key] ||= 1
        # won't assign anything to :key. MK.
        @callbacks  = Hash.new
      end


      def error(exception)
        # Asynchronous error handling.
        # Set callback for given class (Queue for example)
        # or for the Connection class (or instance, of course).
        callbacks = [self.callbacks[:close], self.connection.callbacks[:close]].flatten.compact

        callbacks.map { |c| c.call(exception) } if callbacks.any?
      end
    end
  end
end
