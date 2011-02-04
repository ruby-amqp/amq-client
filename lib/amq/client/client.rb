# encoding: utf-8

module AMQ
  module Client
    # @api public
    def self.connect(settings = nil)
      @settings = AMQ::Client::Settings.configure(settings)
      self.__connect__(@settings)
      self.handshake
    end

    # @api plugin
    def self.__connect__(settings)
      raise MissingInterfaceMethodError.new("AMQ::Client.connect(settings)")
    end

    def self.handshake
      client = self.new
      client.amq_init
      client
    end

    attr_accessor :logger, :settings
    def initialize
      self.logger   = self.class.logger
      self.settings = self.class.settings
    end

    # AMQ::Client interface
    # This has to be implemented by all the clients.
    def amq_init
      self.send_raw(AMQ::Protocol::PREAMBLE)
    end

    def send(data)
      raise MissingInterfaceMethodError.new("AMQ::Client#send(data)")
    end

    def send_raw(data)
      raise MissingInterfaceMethodError.new("AMQ::Client#send_raw(data)")
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
  end
end
