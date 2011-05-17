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
        end
      end
    end



    # AMQ entities, as implemented by AMQ::Client, have callbacks and can run them
    # when necessary.
    #
    # @note Exchanges and queues implementation is based on this class.
    #
    # @abstract
    class Entity

      #
      # Behaviors
      #

      include Openable
      include Callbacks

      extend RegisterEntityMixin

      #
      # API
      #

      # @return [Array<#call>]
      attr_reader :callbacks

      @@handlers ||= Hash.new

      def self.handle(klass, &block)
        @@handlers[klass] = block
      end

      def self.handlers
        @@handlers
      end


      def initialize(client)
        @client    = client
        # Be careful with default values for #ruby hashes: h = Hash.new(Array.new); h[:key] ||= 1
        # won't assign anything to :key. MK.
        @callbacks = Hash.new
      end


      def error(exception)
        # Asynchronous error handling.
        # Set callback for given class (Queue for example)
        # or for the Connection class (or instance, of course).
        callbacks = [self.callbacks[:close], self.client.connection.callbacks[:close]].flatten.compact

        callbacks.map { |c| c.call(exception) } if callbacks.any?
      end
    end
  end
end
