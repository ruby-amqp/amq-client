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
    end
  end
end
