# encoding: utf-8

require "amq/client/logging"
require "amq/client/settings"
require "amq/client/entity"
require "amq/client/connection"

module AMQ
  # For overview of AMQP client adapters API, see {AMQ::Client::Adapter}
  module Client
    # Base adapter class. Specific implementations (for example, EventMachine-based, Cool.io-based or
    # sockets-based) subclass it and must implement Adapter API methods:
    #
    # * #send_raw(data)
    # * #estabilish_connection(settings)
    # * #close_connection
    #
    # Adapters also must indicate whether they operate in asynchronous or synchronous mode
    # using AMQ::Client::Adapter.sync accessor:
    #
    # @example EventMachine adapter indicates that it is asynchronous
    #  module AMQ
    #    module Client
    #      class EventMachineClient
    #
    #        #
    #        # Behaviors
    #        #
    #
    #        include AMQ::Client::Adapter
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
    module Adapter

      def self.included(host)
        host.extend(ClassMethods)

        host.class_eval do
          attr_accessor :logger, :settings, :connection

          # Authentication mechanism
          attr_accessor :mechanism

          # Security response data
          attr_accessor :response

          # The locale defines the language in which the server will send reply texts.
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.2)
          attr_accessor :locale

          # @api plugin
          # @see #disconnect
          # @note Adapters must implement this method but it is NOT supposed to be used directly.
          #       AMQ protocol defines two-step process of closing connection (send Connection.Close
          #       to the peer and wait for Connection.Close-Ok), implemented by {Adapter#disconnect}
          def close_connection
            raise MissingInterfaceMethodError.new("AMQ::Client.close_connection")
          end unless defined?(:close_connection) # since it is a module, this method may already be defined
        end
      end # self.included(host)



      module ClassMethods
        # Settings
        def settings
          @settings ||= AMQ::Client::Settings.default
        end

        def logger
          @logger ||= begin
                        require "logger"
                        Logger.new(STDERR)
                      end
        end

        def logger=(logger)
          methods = AMQ::Client::Logging::REQUIRED_METHODS
          unless methods.all? { |method| logger.respond_to?(method) }
            raise AMQ::Client::Logging::IncompatibleLoggerError.new(methods)
          end

          @logger = logger
        end

        # @return [Boolean] Current value of logging flag.
        def logging
          settings[:logging]
        end

        # Turns loggin on or off.
        def logging=(boolean)
          settings[:logging] = boolean
        end


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

        # Establishes connection to AMQ broker and returns it. New connection object is yielded to
        # the block if it is given.
        #
        # @param [Hash] Connection parameters, including :adapter to use.
        # @api public
        def connect(settings = nil, &block)
          if settings && settings[:adapter]
            adapter = load_adapter(settings[:adapter])
          else
            adapter = self
          end

          @settings = AMQ::Client::Settings.configure(settings)
          instance  = adapter.new
          instance.establish_connection(@settings)
          # We don't need anything more, once the server receives the preable, he sends Connection.Start, we just have to reply.

          if block
            block.call(instance)

            instance.disconnect
          else
            instance
          end
        end


        # Loads adapter from amq/client/adapters.
        #
        # @raise [InvalidAdapterNameError] When loading attempt failed (LoadError was raised).
        def load_adapter(adapter)
          require "amq/client/adapters/#{adapter}"

          const_name = adapter.to_s.gsub(/(^|_)(.)/) { $2.upcase! }
          const_get(const_name)
        rescue LoadError
          raise InvalidAdapterNameError.new(adapter)
        end

        # @see AMQ::Client::Adapter
        def sync=(boolean)
          @sync = boolean
        end

        # Use this method to detect whether adapter is synchronous or asynchronous.
        #
        # @return [Boolean] true if this adapter is synchronous
        # @api plugin
        # @see AMQ::Client::Adapter
        def sync?
          @sync == true
        end

        # @see #sync?
        # @api plugin
        # @see AMQ::Client::Adapter
        def async?
          !sync?
        end
      end # ClassMethods


      #
      # Behaviors
      #

      include AMQ::Client::StatusMixin


      #
      # API
      #

      def self.load_adapter(adapter)
        ClassMethods.load_adapter(adapter)
      end



      def initialize(*args)
        super(*args)

        self.logger   = self.class.logger
        self.settings = self.class.settings

        @frames       = Array.new
      end



      # Establish socket connection to the server.
      #
      # @api plugin
      def establish_connection(settings)
        raise MissingInterfaceMethodError.new("AMQ::Client#establish_connection(settings)")
      end

      def handshake(mechanism = "PLAIN", response = "\0guest\0guest", locale = "en_GB")
        self.send_preamble
        self.connection = AMQ::Client::Connection.new(self, mechanism, response, locale)
        if self.sync?
          self.receive # Start/Start-Ok
          self.receive # Tune/Tune-Ok
        end
      end

      # Properly close connection with AMQ broker, as described in
      # section 2.2.4 of the {http://bit.ly/hw2ELX AMQP 0.9.1 specification}.
      #
      # @api  plugin
      # @todo This method should await broker's response with Close-Ok. {http://github.com/michaelklishin MK}.
      # @see  #close_connection
      def disconnect(reply_code = 200, reply_text = "Goodbye", &block)
        self.on_disconnection(&block)
        closing!
        self.connection.close(reply_code, reply_text)
      end
      alias close disconnect

      # Sends AMQ protocol header (also known as preamble).
      #
      # @note This must be implemented by all AMQP clients.
      # @api plugin
      # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.2)
      def send_preamble
        self.send_raw(AMQ::Protocol::PREAMBLE)
      end

      def send(frame)
        if self.connection.opened? || self.connection.opening?
          self.send_raw(frame.encode)
        else
          raise ConnectionClosedError.new
        end
      end

      def send_frameset(frames)
        frames.each { |frame| self.send(frame) }
      end # send_frameset(frames)


      # Sends opaque data to AMQ broker over active connection.
      #
      # @note This must be implemented by all AMQP clients.
      # @api plugin
      def send_raw(data)
        raise MissingInterfaceMethodError.new("AMQ::Client#send_raw(data)")
      end

      def receive_frame(frame)
        @frames << frame
        if frameset_complete?(@frames)
          receive_frameset(@frames)
          @frames.clear
        else
          # puts "#{frame.inspect} is NOT final"
        end
      end

      # When the adapter receives all the frames related to
      # given method frame, it's supposed to call this method.
      # It calls handler for method class of the first (method)
      # frame with all the other frames as arguments. Handlers
      # are defined in amq/client/* by the handle(klass, &block)
      # method.
      def receive_frameset(frames)
        frame = frames.first

        if Protocol::HeartbeatFrame === frame
          @last_server_heartbeat = Time.now
        else
          callable = AMQ::Client::Entity.handlers[frame.method_class]
          if callable
            callable.call(self, frames.first, frames[1..-1])
          else
            raise MissingHandlerError.new(frames.first)
          end
        end
      end

      def send_heartbeat
        if tcp_connection_established?
          if @last_server_heartbeat < (Time.now - (self.heartbeat_interval * 2))
            logger.error "Reconnecting due to missing server heartbeats"
            # TODO: reconnect
          end
          send(Protocol::HeartbeatFrame)
        end
      end # send_heartbeat


      # @see .sync?
      # @api plugin
      # @see AMQ::Client::Adapter
      def sync?
        self.class.sync?
      end

      # @see .async?
      # @api plugin
      # @see AMQ::Client::Adapter
      def async?
        self.class.async?
      end

      # Returns heartbeat interval this client uses, in seconds.
      # This value may or may not be used depending on broker capabilities.
      #
      # @return  [Fixnum]  Heartbeat interval this client uses, in seconds.
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.6)
      def heartbeat_interval
        @settings[:heartbeat] || @settings[:heartbeat_interval] || 0
      end # heartbeat_interval

      protected

      # Utility methods

      # Determines, whether the received frameset is ready to be further processed
      def frameset_complete?(frames)
        return false if frames.empty?
        first_frame = frames[0]
        first_frame.final? || (first_frame.method_class.has_content? && content_complete?(frames[1..-1]))
      end

      # Determines, whether given frame array contains full content body
      def content_complete?(frames)
        return false if frames.empty?
        header = frames[0]
        raise "Not a content header frame first: #{header.inspect}" unless header.kind_of?(AMQ::Protocol::HeaderFrame)
        header.body_size == frames[1..-1].inject(0) {|sum, frame| sum + frame.payload.size }
      end

    end # Adapter
  end # Client
end # AMQ

require "amq/client/channel"
