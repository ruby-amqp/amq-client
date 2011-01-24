# encoding: utf-8

module AMQ
  module Client
    class MissingInterfaceMethodError < NotImplementedError
      def initialize
        super("This is supposed to be redefined ......")
      end
    end

    class MissingHandlerError < StandardError
      def initialize(frame)
        super("No callback registered for #{frame.method_class}")
      end
    end

    def self.register_io_adapter(adapter)
      load_amq_protocol
      AMQ::Protocol::Frame.extend(adapter)
    end

    def self.load_amq_protocol
      require "amq/protocol/client"
    rescue LoadError => exception
      if exception.message.match("amq/protocol/client")
        raise LoadError.new("You have to install amq-protocol library first!")
      else
        raise exception
      end
    end

    # AMQ::Client interface
    # This has to be implemented by all the clients.
    def send(data)
      raise MissingInterfaceMethodError.new
    end

    def receive_frame(frame)
      @frames << frame
    end

    def receive_frameset(frames)
      callable = @@handlers[frame.method_class].call(frames.first)
      if callable
        callable.call(*frames)
      else
        raise MissingHandlerError.new(frames.first)
      end
    end

    @@handlers ||= Hash.new
    def self.handle(klass, &block)
      @@handlers[klass] = block
    end


    class Entity
      attr_reader :callbacks
      def initialize(adapter)
        @adapter, @callbacks = adapter, Hash.new
      end

      def exec_callback(name, *args)
        callback = self.callbacks[name]
        callback.call(self, *args)
      end
    end
  end
end
