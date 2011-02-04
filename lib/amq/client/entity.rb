# encoding: utf-8

module AMQ
  module Client
    class Entity
      attr_reader :callbacks
      def initialize(adapter)
        @adapter, @callbacks = adapter, Hash.new
      end

      def exec_callback(name, *args, &block)
        callback = self.callbacks[name]
        callback.call(self, *args, &block)
      end
    end
  end
end
