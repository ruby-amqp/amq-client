# encoding: utf-8

require "amq/client/mixins/status"

module AMQ
  module Client
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

      include StatusMixin

      #
      # API
      #

      @@handlers ||= Hash.new

      def self.handle(klass, &block)
        @@handlers[klass] = block
      end

      def self.handlers
        @@handlers
      end

      attr_reader :callbacks

      def initialize(client)
        @client, @callbacks = client, Hash.new
      end

      def exec_callback(name, *args, &block)
        callback = self.callbacks[name]
        callback.call(*args, &block) if callback
      end

      def exec_callback_once(name, *args, &block)
        callback = self.callbacks.delete(name)
        callback.call(*args, &block) if callback
      end

      def exec_callback_yielding_self(name, *args, &block)
        callback = self.callbacks[name]
        callback.call(self, *args, &block) if callback
      end

      def exec_callback_once_yielding_self(name, *args, &block)
        callback = self.callbacks.delete(name)
        callback.call(self, *args, &block) if callback
      end



      def error(exception)
        if client.sync? # DO NOT DO THIS, just add a default errback to do exactly this, so if someone wants to use begin/rescue, he'll just ignore the errbacks.
          # Synchronous error handling.
          # Just use begin/rescue in the main loop.
          raise exception
        else
          # Asynchronous error handling.
          # Set callback for given class (Queue for example)
          # or for the Connection class (or instance, of course).
          callbacks = [self.callbacks[:close], self.client.connection.callbacks[:close]]
          callback  = callbacks.find { |callback| callback }
          callback.call(exception) if callback
        end
      end
    end
  end
end
