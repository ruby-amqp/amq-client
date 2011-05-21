module AMQ
  module Client
    module Callbacks

      def redefine_callback(event, callable = nil, &block)
        f = (callable || block)
        # yes, re-assign!
        @callbacks[event] = [f]

        self
      end

      def define_callback(event, callable = nil, &block)
        f = (callable || block)

        @callbacks[event] ||= []
        @callbacks[event] << f if f

        self
      end # define_callback(event, &block)
      alias append_callback define_callback

      def prepend_callback(event, &block)
        @callbacks[event] ||= []
        @callbacks[event].unshift(block)

        self
      end # prepend_callback(event, &block)

      def clear_callbacks(event)
        @callbacks[event].clear if @callbacks[event]
      end # clear_callbacks(event)


      def exec_callback(name, *args, &block)
        list = Array(self.callbacks[name])
        list.each { |c| c.call(*args, &block) } if list.any?
      end

      def exec_callback_once(name, *args, &block)
        list = Array(self.callbacks.delete(name))
        list.each { |c| c.call(*args, &block) } if list.any?
      end

      def exec_callback_yielding_self(name, *args, &block)
        list = Array(self.callbacks[name])
        list.each { |c| c.call(self, *args, &block) } if list.any?
      end

      def exec_callback_once_yielding_self(name, *args, &block)
        list = Array(self.callbacks.delete(name))
        list.each { |c| c.call(self, *args, &block) } if list.any?
      end

      def has_callback?(name)
        self.callbacks[name] && !self.callbacks[name].empty?
      end # has_callback?
    end # Callbacks
  end # Client
end # AMQ
