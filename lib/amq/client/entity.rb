# encoding: utf-8

require "amq/client/mixins/status"

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

      include StatusMixin
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
        callbacks = Array(self.callbacks[name])
        callbacks.map { |c| c.call(*args, &block) } if callbacks.any?
      end

      def exec_callback_once(name, *args, &block)
        callbacks = Array(self.callbacks.delete(name))
        callbacks.map { |c| c.call(*args, &block) } if callbacks.any?
      end

      def exec_callback_yielding_self(name, *args, &block)
        callbacks = Array(self.callbacks[name])
        callbacks.map { |c| c.call(self, *args, &block) } if callbacks.any?
      end

      def exec_callback_once_yielding_self(name, *args, &block)
        callbacks = Array(self.callbacks.delete(name))
        callbacks.map { |c| c.call(self, *args, &block) } if callbacks.any?
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
          callbacks = [self.callbacks[:close], self.client.connection.callbacks[:close]].flatten.compact

          callbacks.map { |c| c.call(exception) } if callbacks.any?
        end
      end
    end
  end
end
