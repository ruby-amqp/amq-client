# encoding: utf-8

module AMQ
  module Client
    class Entity
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
        callback.call(self, *args, &block)
      end

      def error(exception)
        if client.is_a?(AMQ::SocketClient)
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
