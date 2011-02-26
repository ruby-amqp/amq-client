# encoding: utf-8

require "amq/client/logging"
require "amq/client/settings"
require "amq/client/entity"
require "amq/client/amqp/connection"

module AMQ
  # For overview of AMQP client adapters API, see {AMQ::Client::Adapter}
  module Client
    # Syntactic sugar for logging setting.
    #
    # @see AMQ::Client::Adapter
    module Logging
      def self.logging
        AMQ::Client::Adapter.logging
      end

      def self.logging=(boolean)
        AMQ::Client::Adapter.logging = boolean
      end
    end

    # Base adapter class. Specific implementations (for example, EventMachine-based, Cool.io-based or
    # sockets-based) subclass it and must implement Adapter API methods:
    #
    # * #send_raw(data)
    # * #estabilish_connection(settings)
    # * #disconnect
    #
    # Adapters also must indicate whether they operate in asynchronous or synchronous mode
    # using AMQ::Client::Adapter.sync accessor:
    #
    # @example EventMachine adapter indicates that it is asynchronous
    #  module AMQ
    #    module Client
    #      class EventMachineClient < AMQ::Client::Adapter
    #
    #        #
    #        # Behaviors
    #        #
    #
    #        include EventMachine::Deferrable
    #
    #         self.sync = false
    #
    #         # the rest of implementation code ...
    #
    #       end
    #     end
    #   end
    #
    # @abstract
    class Adapter
      # Settings
      def self.settings
        @settings ||= AMQ::Client::Settings.default
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
          raise AMQ::Client::Logging::IncompatibleLoggerError.new(methods)
        end

        @logger = logger
      end

      # @return [Boolean] Current value of logging flag.
      def self.logging
        self.settings[:logging]
      end

      # Turns loggin on or off.
      def self.logging=(boolean)
        self.settings[:logging] = boolean
      end


      # @example Registering Channel implementation
      #  Adapter.register_entity(:channel, Channel)
      #   # ... so then I can do:
      #  channel = client.channel(1)
      #  # instead of:
      #  channel = Channel.new(client, 1)
      def self.register_entity(name, klass)
        define_method(name) do |*args, &block|
          klass.new(self, *args, &block)
        end
      end

      # Establishes connection to AMQ broker and returns it. New connection object is yielded to
      # the block if it is given.
      #
      # @param [Hash] Connection parameters, including :adapter to use.
      # @api public
      def self.connect(settings = nil, &block)
        if self.class != Adapter
          adapter = self
        elsif self.class == Adapter && settings && settings[:adapter] # not for subclasses
          adapter = self.load_adapter(settings[:adapter])
        else
          raise "XXX", "you have to use either given adapter directly by calling its .connect method or you have to specify :adapter option in the settings."
        end

        @settings = AMQ::Client::Settings.configure(settings)
        instance = adapter.new
        instance.establish_connection(@settings)
        # We don't need anything more, once the server receives the preable, he sends Connection.Start, we just have to reply.

        if block
          block.call(instance)
          instance.connection.close
          instance.disconnect
        else
          instance
        end
      end

      # Loads adapter from amq/client/adapters.
      #
      # @raise [InvalidAdapterNameError] When loading attempt failed (LoadError was raised).
      def self.load_adapter(adapter)
        require "amq/client/adapters/#{adapter}"
        const_name = adapter.to_s.gsub(/(^|_)(.)/) { $2.upcase! }
        self.const_get(const_name)
      rescue LoadError
        raise InvalidAdapterNameError.new(adapter)
      end

      # Establish socket connection to the server.
      #
      # @api plugin
      def establish_connection(settings)
        raise MissingInterfaceMethodError.new("AMQ::Client#establish_connection(settings)")
      end

      # @api plugin
      # @see #close_connection
      # @note Adapters must implement this method but it is NOT supposed to be used directly.
      #       AMQ protocol defines two-step process of closing connection (send Connection.Close
      #       to the peer and wait for Connection.Close-Ok), implemented by {Adapter#close_connection}
      def disconnect
        raise MissingInterfaceMethodError.new("AMQ::Client.disconnect")
      end

      attr_accessor :logger, :settings, :connection
      attr_accessor :mechanism, :response, :locale
      def initialize
        self.logger   = self.class.logger
        self.settings = self.class.settings

        @frames = Array.new
      end

      def handshake(mechanism = "PLAIN", response = "\0guest\0guest", locale = "en_GB")
        self.send_preamble
        self.connection = AMQ::Client::Connection.new(self, mechanism, response, locale)
        if self.sync?
          self.receive # Start/Start-Ok
          self.receive # Tune/Tune-Ok
        end
      end

      # @see AMQ::Client::Adapter
      def self.sync=(boolean)
        @sync = boolean
      end

      # Use this method to detect whether adapter is synchronous or asynchronous.
      #
      # @return [Boolean] true if this adapter is synchronous
      # @api plugin
      # @see AMQ::Client::Adapter
      def self.sync?
        @sync == true
      end

      # @see .sync?
      # @api plugin
      # @see AMQ::Client::Adapter
      def sync?
        self.class.sync?
      end

      # @see #sync?
      # @api plugin
      # @see AMQ::Client::Adapter
      def self.async?
        ! self.sync?
      end

      # @see .async?
      # @api plugin
      # @see AMQ::Client::Adapter
      def async?
        self.class.async?
      end

      # Sends AMQ protocol header (also known as preamble).
      #
      # @note This must be implemented by all AMQP clients.
      # @api plugin
      # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.2)
      def send_preamble
        self.send_raw(AMQ::Protocol::PREAMBLE)
      end

      def send(frame) # TODO: log frames
        if self.connection.opened?
          self.send_raw(frame.encode)
        else
          raise ConnectionClosedError.new
        end
      end

      # Sends opaque data to AMQ broker over active connection.
      #
      # @note This must be implemented by all AMQP clients.
      # @api plugin
      def send_raw(data)
        raise MissingInterfaceMethodError.new("AMQ::Client#send_raw(data)")
      end

      def receive_frame(frame)
        @frames << frame
        if frame.final?
          receive_frameset(@frames)
          @frames.clear
        end
      end

      # When the adapter receives all the frames related to
      # given method frame, it's supposed to call this method.
      # It calls handler for method class of the first (method)
      # frame with all the other frames as arguments. Handlers
      # are defined in amq/client/amqp/* by the handle(klass, &block)
      # method.
      def receive_frameset(frames)
        frame = frames.first
        callable = AMQ::Client::Entity.handlers[frame.method_class]
        if callable
          callable.call(self, frames.first, *frames[1..-1])
        else
          raise MissingHandlerError.new(frames.first)
        end
      end

      # Properly close connection with AMQ broker, as described in
      # section 2.2.4 of the {http://bit.ly/hw2ELX AMQP 0.9.1 specification}.
      #
      # @api  plugin
      # @todo This method should await broker's response with Close-Ok. {http://github.com/michaelklishin MK}.
      # @see  #disconnect
      def close_connection
        send AMQ::Protocol::Connection::Close.encode
        self.disconnect
      end

      def get_random_channel
        keys = self.connection.keys
        random_key = keys[rand(keys.length)]
        self.connection.channels[random_key]
      end
    end
  end
end

require "amq/client/amqp/channel"
