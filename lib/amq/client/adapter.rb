# encoding: utf-8

require "amq/client/logging"
require "amq/client/settings"
require "amq/client/entity"
require "amq/client/channel"

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
    # @abstract
    module Adapter

      def self.included(host)
        host.extend ClassMethods
        host.extend ProtocolMethodHandlers

        host.class_eval do

          #
          # Behaviors
          #

          include Entity



          #
          # API
          #

          attr_accessor :logger
          attr_accessor :settings
          attr_accessor :connection

          # The locale defines the language in which the server will send reply texts.
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.2)
          attr_accessor :locale

          # Client capabilities
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.2.1)
          attr_accessor :client_properties

          # Server capabilities
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
          attr_reader :server_properties

          # Authentication mechanism used.
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.2)
          attr_reader :mechanism

          # Channels within this connection.
          #
          # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.2.5)
          attr_reader :channels

          # Maximum channel number that the server permits this connection to use.
          # Usable channel numbers are in the range 1..channel_max.
          # Zero indicates no specified limit.
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Sections 1.4.2.5.1 and 1.4.2.6.1)
          attr_accessor :channel_max

          # Maximum frame size that the server permits this connection to use.
          #
          # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Sections 1.4.2.5.2 and 1.4.2.6.2)
          attr_accessor :frame_max


          attr_reader :known_hosts



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


        # Establishes connection to AMQ broker and returns it. New connection object is yielded to
        # the block if it is given.
        #
        # @example Specifying adapter via the :adapter option
        #   AMQ::Client::Adapter.connect(:adapter => "socket")
        # @example Specifying using custom adapter class
        #   AMQ::Client::SocketClient.connect
        # @param [Hash] Connection parameters, including :adapter to use.
        # @api public
        def connect(settings = nil, &block)
          @settings = Settings.configure(settings)

          instance = self.new
          instance.establish_connection(settings)
          instance.register_connection_callback(&block)

          instance
        end


        # Can be overriden by higher-level libraries like amqp gem or bunny.
        # Defaults to AMQ::Client::TCPConnectionFailed.
        #
        # @return [Class]
        def tcp_connection_failure_exception_class
          @tcp_connection_failure_exception_class ||= AMQ::Client::TCPConnectionFailed
        end # tcp_connection_failure_exception_class

        # Can be overriden by higher-level libraries like amqp gem or bunny.
        # Defaults to AMQ::Client::PossibleAuthenticationFailure.
        #
        # @return [Class]
        def authentication_failure_exception_class
          @authentication_failure_exception_class ||= AMQ::Client::PossibleAuthenticationFailureError
        end # authentication_failure_exception_class
      end # ClassMethods


      #
      # Behaviors
      #

      include AMQ::Client::Openable

      extend RegisterEntityMixin

      register_entity :channel,  AMQ::Client::Channel


      #
      # API
      #


      # Establish socket connection to the server.
      #
      # @api plugin
      def establish_connection(settings)
        raise MissingInterfaceMethodError.new("AMQ::Client#establish_connection(settings)")
      end

      # Properly close connection with AMQ broker, as described in
      # section 2.2.4 of the {http://bit.ly/hw2ELX AMQP 0.9.1 specification}.
      #
      # @api  plugin
      # @see  #close_connection
      def disconnect(reply_code = 200, reply_text = "Goodbye", class_id = 0, method_id = 0, &block)
        @intentionally_closing_connection = true
        self.on_disconnection(&block)

        # ruby-amqp/amqp#66, MK.
        if self.open?
          closing!
          self.send Protocol::Connection::Close.encode(reply_code, reply_text, class_id, method_id)
        elsif self.closing?
          # no-op
        else
          self.disconnection_successful
        end
      end


      # Sends AMQ protocol header (also known as preamble).
      #
      # @note This must be implemented by all AMQP clients.
      # @api plugin
      # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.2)
      def send_preamble
        self.send_raw(AMQ::Protocol::PREAMBLE)
      end

      # Sends frame to the peer, checking that connection is open.
      #
      # @raise [ConnectionClosedError]
      def send(frame)
        if closed?
          raise ConnectionClosedError.new(frame)
        else
          self.send_raw(frame.encode)
        end
      end

      # Sends multiple frames, one by one.
      #
      # @api public
      def send_frameset(frames)
        frames.each { |frame| self.send(frame) }
      end # send_frameset(frames)



      # Returns heartbeat interval this client uses, in seconds.
      # This value may or may not be used depending on broker capabilities.
      # Zero means the server does not want a heartbeat.
      #
      # @return  [Fixnum]  Heartbeat interval this client uses, in seconds.
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.6)
      def heartbeat_interval
        @settings[:heartbeat] || @settings[:heartbeat_interval] || 0
      end # heartbeat_interval


      # vhost this connection uses. Default is "/", a historically estabilished convention
      # of RabbitMQ and amqp gem.
      #
      # @return [String] vhost this connection uses
      # @api public
      def vhost
        @settings.fetch(:vhost, "/")
      end # vhost


      # Called when previously established TCP connection fails.
      # @api public
      def tcp_connection_lost
        @on_tcp_connection_loss.call(self, @settings) if @on_tcp_connection_loss
      end

      # Called when initial TCP connection fails.
      # @api public
      def tcp_connection_failed
        @on_tcp_connection_failure.call(@settings) if @on_tcp_connection_failure
      end



      #
      # Implementation
      #


      # Sends opaque data to AMQ broker over active connection.
      #
      # @note This must be implemented by all AMQP clients.
      # @api plugin
      def send_raw(data)
        raise MissingInterfaceMethodError.new("AMQ::Client#send_raw(data)")
      end

      # Sends connection preamble to the broker.
      # @api plugin
      def handshake
        @authenticating = true
        self.send_preamble
      end


      # Sends connection.open to the server.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.7)
      def open(vhost = "/")
        self.send Protocol::Connection::Open.encode(vhost)
      end

      # Resets connection state.
      #
      # @api plugin
      def reset_state!
        # no-op by default
      end # reset_state!

      # @api plugin
      # @see http://tools.ietf.org/rfc/rfc2595.txt RFC 2595
      def encode_credentials(username, password)
        "\0#{username}\0#{password}"
      end # encode_credentials(username, password)


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
          callable = AMQ::Client::HandlersRegistry.find(frame.method_class)
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



      # Handles Connection.Start.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.1.)
      def start_ok(method)
        @server_properties = method.server_properties

        username = @settings[:user] || @settings[:username]
        password = @settings[:pass] || @settings[:password]

        # It's not clear whether we should transition to :opening state here
        # or in #open but in case authentication fails, it would be strange to have
        # @status undefined. So lets do this. MK.
        opening!

        self.send Protocol::Connection::StartOk.encode(@client_properties, @mechanism, self.encode_credentials(username, password), @locale)
      end


      # Handles Connection.Open-Ok.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.8.)
      def handle_open_ok(method)
        @known_hosts = method.known_hosts

        opened!
        self.connection_successful if self.respond_to?(:connection_successful)
      end

      # Handles Connection.Tune-Ok.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.6)
      def handle_tune(method)
        @channel_max        = method.channel_max
        @frame_max          = method.frame_max
        @heartbeat_interval = self.heartbeat_interval || method.heartbeat

        self.send Protocol::Connection::TuneOk.encode(@channel_max, [settings[:frame_max], @frame_max].min, @heartbeat_interval)
      end # handle_tune(method)


      # Handles connection.close. When broker detects a connection level exception, this method is called.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.5.2.9)
      def handle_close(method)
        self.handle_connection_interruption

        closed!
        # TODO: use proper exception class, provide protocol class (we know method.class_id and method.method_id) as well!
        error = RuntimeError.new(method.reply_text)
        self.error(error)
      end


      # Handles Connection.Close-Ok.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.10)
      def handle_close_ok(method)
        closed!
        self.disconnection_successful
      end # handle_close_ok(method)

      # @api plugin
      def handle_connection_interruption
        @channels.each { |n, c| c.handle_connection_interruption }
      end # handle_connection_interruption



      protected

      # Returns next frame from buffer whenever possible
      #
      # @api private
      def get_next_frame
        return nil unless @chunk_buffer.size > 7 # otherwise, cannot read the length
        # octet + short
        offset = 3 # 1 + 2
        # length
        payload_length = @chunk_buffer[offset, 4].unpack('N')[0]
        # 4 bytes for long payload length, 1 byte final octet
        frame_length = offset + 4 + payload_length + 1
        if frame_length <= @chunk_buffer.size
          @chunk_buffer.slice!(0, frame_length)
        else
          nil
        end
      end # def get_next_frame

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
