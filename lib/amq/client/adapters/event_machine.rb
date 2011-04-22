# encoding: utf-8

require "eventmachine"
require "amq/client"
require "amq/client/framing/string/frame"

module AMQ
  module Client
    class EventMachineClient < EM::Connection
      # @private
      class Deferrable
        include EventMachine::Deferrable
      end

      #
      # Behaviors
      #

      include AMQ::Client::Adapter

      self.sync = false

      #
      # API
      #

      def self.connect(settings = nil, &block)
        @settings = Settings.configure(settings)

        instance = EventMachine.connect(@settings[:host], @settings[:port], self, @settings)
        instance.register_connection_callback(&block)

        instance
      end

      # Reconnect after a period of wait.
      #
      # @param [Fixnum]  period Period of time, in seconds, to wait before reconnection attempt.
      # @param [Boolean] force  If true, enforces immediate reconnection.
      # @api public
      def reconnect(force = false, period = 5)
        if @reconnecting and not force
          EventMachine::Timer.new(period) {
            reconnect(true, period)
          }
          return
        end

        if !@reconnecting
          @reconnecting = true
          @connections.each { |c| c.handle_connection_interruption }
          self.reset
        end

        EventMachine.reconnect(@settings[:host], @settings[:port], self)
      end

      # For EventMachine adapter, this is a no-op.
      # @api public
      def establish_connection(settings)
        # Unfortunately there doesn't seem to be any sane way
        # how to get EventMachine connect to the instance level.
      end

      # @see #on_connection
      # @private
      def register_connection_callback(&block)
        unless block.nil?
          # delay calling block we were given till after we receive
          # connection.open-ok. Connection will notify us when
          # that happens.
          self.on_connection do
            block.call(self)
          end
        end
      end


      attr_reader :connections


      def initialize(*args)
        super(*args)

        @connections                        = Array.new
        # track TCP connection state, used to detect initial TCP connection failures.
        @tcp_connection_established       = false
        @tcp_connection_failed            = false
        @intentionally_closing_connection = false

        # EventMachine::Connection's and Adapter's constructors arity
        # make it easier to use *args. MK.
        @settings                           = args.first
        @on_possible_authentication_failure = @settings[:on_possible_authentication_failure]
        @on_tcp_connection_failure          = @settings[:on_tcp_connection_failure] || Proc.new { |settings|
          raise AMQ::Client::TCPConnectionFailed.new(settings)
        }

        self.reset

        self.set_pending_connect_timeout((@settings[:timeout] || 3).to_f) unless defined?(JRUBY_VERSION)

        if self.heartbeat_interval > 0
          @last_server_heartbeat = Time.now
          EventMachine.add_periodic_timer(self.heartbeat_interval, &method(:send_heartbeat))
        end
      end # initialize(*args)


      alias send_raw send_data

      # Whether we are in authentication state (after TCP connection was estabilished
      # but before broker authenticated us).
      #
      # @return [Boolean]
      # @api public
      def authenticating?
        @authenticating
      end # authenticating?

      # IS TCP connection estabilished and currently active?
      # @return [Boolean]
      # @api public
      def tcp_connection_established?
        @tcp_connection_established
      end # tcp_connection_established?

      #
      # Implementation
      #

      # EventMachine reactor callback. Is run when TCP connection is estabilished
      # but before resumption of the network loop. Note that this includes cases
      # when TCP connection has failed.
      # @private
      def post_init
        reset

        # note that upgrading to TLS in #connection_completed causes
        # Erlang SSL app that RabbitMQ relies on to report
        # error on TCP connection <0.1465.0>:{ssl_upgrade_error,"record overflow"}
        # and close TCP connection down. Investigation of this issue is likely
        # to take some time and to not be worth in as long as #post_init
        # works fine. MK.
        upgrade_to_tls_if_necessary
      rescue Exception => error
        raise error
      end # post_init

      # Called by EventMachine reactor once TCP connection is successfully estabilished.
      # @private
      def connection_completed
        # we only can safely set this value here because EventMachine is a lovely piece of
        # software that calls #post_init before #unbind even when TCP connection
        # fails. MK.
        @tcp_connection_established       = true
        # again, this is because #unbind is called in different situations
        # and there is no easy way to tell initial connection failure
        # from connection loss. Not in EventMachine 0.12.x, anyway. MK.
        @had_successfull_connected_before = true

        @reconnecting                     = false

        self.handshake
      end

      # @private
      def close_connection(*args)
        @intentionally_closing_connection = true

        super(*args)
      end

      # Called by EventMachine reactor when
      #
      # * We close TCP connection down
      # * Our peer closes TCP connection down
      # * There is a network connection issue
      # * Initial TCP connection fails
      # @private
      def unbind(exception = nil)
        if !@tcp_connection_established && !@had_successfull_connected_before
          @tcp_connection_failed = true
          self.tcp_connection_failed
        end

        closing!
        @tcp_connection_established = false

        @connections.each { |c| c.handle_connection_interruption }
        @disconnection_deferrable.succeed

        closed!


        self.tcp_connection_lost if !@intentionally_closing_connection && @had_successfull_connected_before

        # since AMQP spec dictates that authentication failure is a protocol exception
        # and protocol exceptions result in connection closure, check whether we are
        # in the authentication stage. If so, it is likely to signal an authentication
        # issue. Java client behaves the same way. MK.
        if authenticating?
          if sync?
            raise PossibleAuthenticationFailureError.new(@settings)
          else
            @on_possible_authentication_failure.call(@settings) if @on_possible_authentication_failure
          end
        end
      end # unbind


      #
      # EventMachine receives data in chunks, sometimes those chunks are smaller
      # than the size of AMQP frame. That's why you need to add some kind of buffer.
      #
      # @private
      def receive_data(chunk)
        @chunk_buffer << chunk
        while frame = get_next_frame
          self.receive_frame(AMQ::Client::Framing::String::Frame.decode(frame))
        end
      end

      # Defines a callback that will be executed when AMQP connection is considered open,
      # after client and broker has agreed on max channel identifier and maximum allowed frame
      # size. You can define more than one callback.
      #
      # @see #on_open
      # @api public
      def on_connection(&block)
        @connection_deferrable.callback(&block)
      end # on_connection(&block)

      # Called by AMQ::Client::Connection after we receive connection.open-ok.
      # @api public
      def connection_successful
        @connection_deferrable.succeed
      end # connection_successful


      # Defines a callback that will be executed when AMQP connection is considered open,
      # before client and broker has agreed on max channel identifier and maximum allowed frame
      # size. You can define more than one callback.
      #
      # @see #on_connection
      # @api public
      def on_open(&block)
        @connection_opened_deferrable.callback(&block)
      end # on_open(&block)

      # Called by AMQ::Client::Connection after we receive connection.tune.
      # @api public
      def open_successful
        @authenticating = false
        @connection_opened_deferrable.succeed

        opened!
      end # open_successful


      # Defines a callback that will be run when broker confirms connection termination
      # (client receives connection.close-ok). You can define more than one callback.
      #
      # @api public
      def on_disconnection(&block)
        @disconnection_deferrable.callback(&block)
      end # on_disconnection(&block)

      # Called by AMQ::Client::Connection after we receive connection.close-ok.
      #
      # @api public
      def disconnection_successful
        @disconnection_deferrable.succeed

        self.close_connection
        self.reset
        closed!
      end # disconnection_successful


      # Defines a callback that will be run when initial TCP connection fails.
      # You can define only one callback.
      #
      # @api public
      def on_tcp_connection_failure(&block)
        @on_tcp_connection_failure = block
      end

      # Called when initial TCP connection fails.
      # @api public
      def tcp_connection_failed
        @on_tcp_connection_failure.call(@settings) if @on_tcp_connection_failure
      end


      # Defines a callback that will be run when initial TCP connection fails.
      # You can define only one callback.
      #
      # @api public
      def on_tcp_connection_loss(&block)
        @on_tcp_connection_loss = block
      end

      # Called when initial TCP connection fails.
      # @api public
      def tcp_connection_lost
        @on_tcp_connection_loss.call(self, @settings) if @on_tcp_connection_loss
      end



      # Defines a callback that will be run when TCP connection is closed before authentication
      # finishes. Usually this means authentication failure. You can define only one callback.
      #
      # @api public
      def on_possible_authentication_failure(&block)
        @on_possible_authentication_failure = block
      end


      protected

      def handshake(mechanism = "PLAIN", response = nil, locale = "en_GB")
        username = @settings[:user] || @settings[:username]
        password = @settings[:pass] || @settings[:password]

        # self.logger.info "[authentication] Credentials are #{username}/#{'*' * password.bytesize}"

        self.connection = AMQ::Client::Connection.new(self, mechanism, self.encode_credentials(username, password), locale)

        @authenticating = true
        self.send_preamble
      end

      def reset
        @size    = 0
        @payload = ""
        @frames  = Array.new

        @chunk_buffer                 = ""
        @connection_deferrable        = Deferrable.new
        @disconnection_deferrable     = Deferrable.new
        # succeeds when connection is open, that is, vhost is selected
        # and client is given green light to proceed.
        @connection_opened_deferrable = Deferrable.new

        # used to track down whether authentication succeeded. AMQP 0.9.1 dictates
        # that on authentication failure broker must close TCP connection without sending
        # any more data. This is why we need to explicitly track whether we are past
        # authentication stage to signal possible authentication failures.
        @authenticating           = false
      end

      # @see http://tools.ietf.org/rfc/rfc2595.txt RFC 2595
      def encode_credentials(username, password)
        "\0#{username}\0#{password}"
      end # encode_credentials(username, password)

      def get_next_frame
        return unless @chunk_buffer.size > 7 # otherwise, cannot read the length
        # octet + short
        offset = 3 # 1 + 2
        # length
        payload_length = @chunk_buffer[offset, 4].unpack('N')[0]
        # 5: 4 bytes for long payload length, 1 byte final octet
        frame_length = offset + 5 + payload_length
        if frame_length <= @chunk_buffer.size
          @chunk_buffer.slice!(0, frame_length)
        else
          nil
        end
      end # get_next_frame

      def upgrade_to_tls_if_necessary
        tls_options = @settings[:ssl]

        if tls_options.is_a?(Hash)
          start_tls(tls_options)
        elsif tls_options
          start_tls
        end
      end
    end # EventMachineClient
  end # Client
end # AMQ
