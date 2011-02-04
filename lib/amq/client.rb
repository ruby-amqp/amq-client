# encoding: utf-8

require "amq/client/logging"
require "amq/client/exceptions"

module AMQ
  module Client
    # Let's integrate logging.
    module Logging
      def self.logging
        AMQ::Client.logging
      end

      def self.logging=(boolean)
        AMQ::Client.logging = boolean
      end
    end

    def self.logger
      @logger ||= begin
        require "logger"
        Logger.new(STDERR)
      end
    end

    def self.logger=(logger)
      methods = AMQ::Client::Logging::REQUIRED_METHODS
      unless methods.all? { |method| logger.respond_to?(method) }
        raise AMQ::Client::Logging::IncompatibleLoggerError.new
      end

      @logger = logger
    end

    def self.logging
      @settings[:logging]
    end

    def self.logging=(boolean)
      @settings[:logging] = boolean
    end

    def self.register_io_adapter(adapter)
      load_amq_protocol
      AMQ::Protocol::Frame.extend(adapter) # FIXME: what if one want to use more adapters in the same app? I. e. during the rewrite ...
    end

    def self.load_amq_protocol(path = "client")
      require "amq/protocol/#{path}"
    rescue LoadError => exception
      if exception.message.match("amq/protocol")
        raise LoadError.new("You have to install amq-protocol library first!")
      else
        raise exception
      end
    end

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

    def self.logger
      @logger ||= begin
        require "logger"
        Logger.new(STDERR)
      end
    end

    def self.logger=(logger)
      methods = AMQ::Client::Logging::REQUIRED_METHODS
      unless methods.all? { |method| logger.respond_to?(method) }
        raise AMQ::Client::Logging::IncompatibleLoggerError.new
      end

      @logger = logger
    end

    attr_accessor :logger, :settings
    def initialize
      self.logger   = self.class.logger
      self.settings = self.class.settings
    end

    def self.logging
      @settings[:logging]
    end

    def self.logging=(boolean)
      @settings[:logging] = boolean
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
