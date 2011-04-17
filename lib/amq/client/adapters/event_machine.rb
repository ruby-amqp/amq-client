# encoding: utf-8

require "amq/client"
require "amq/client/channel"
require "amq/client/exchange"
require "amq/client/framing/string/frame"

require "eventmachine"

module AMQ
  module Client
    class EventMachineClient < EM::Connection

      class Deferrable
        include EventMachine::Deferrable
      end

      #
      # Behaviors
      #

      include AMQ::Client::Adapter

      self.sync = false

      register_entity :channel,  AMQ::Client::Channel
      register_entity :exchange, AMQ::Client::Exchange

      #
      # API
      #

      def self.connect(settings = nil, &block)
        settings = AMQ::Client::Settings.configure(settings)
        instance = EM.connect(settings[:host], settings[:port], self, settings)

        unless block.nil?
          # delay calling block we were given till after we receive
          # connection.open-ok. Connection will notify us when
          # that happens.
          instance.on_connection do
            block.call(instance)
          end
        end

        instance
      end


      attr_reader :connections


      def initialize(*args)
        super(*args)

        # EventMachine::Connection's and Adapter's constructors arity
        # make it easier to use *args. MK.
        @settings                 = args.first
        @connections              = Array.new
        @on_possible_authentication_failure = @settings[:on_possible_authentication_failure]

        @chunk_buffer             = ""
        @connection_deferrable    = Deferrable.new
        @disconnection_deferrable = Deferrable.new

        @authenticating           = false

        # succeeds when connection is open, that is, vhost is selected
        # and client is given green light to proceed.
        @connection_opened_deferrable = Deferrable.new

        @tcp_connection_established   = false

        if self.heartbeat_interval > 0
          @last_server_heartbeat = Time.now
          EM.add_periodic_timer(self.heartbeat_interval, &method(:send_heartbeat))
        end
      end # initialize(*args)


      def establish_connection(settings)
        # an intentional no-op
      end

      alias send_raw send_data


      def authenticating?
        @authenticating
      end # authenticating?

      def tcp_connection_established?
        @tcp_connection_established
      end # tcp_connection_established?

      #
      # Implementation
      #

      # EventMachine reactor callback. Is run when TCP connection is estabilished
      # but before resumption of the network loop.
      def post_init
        reset

        @tcp_connection_established = true
        # note that upgrading to TLS in #connection_completed causes
        # Erlang SSL app that RabbitMQ relies on to report
        # error on TCP connection <0.1465.0>:{ssl_upgrade_error,"record overflow"}
        # and close TCP connection down. Investigation of this issue is likely
        # to take some time and to not be worth in as long as #post_init
        # works fine. MK.
        upgrade_to_tls_if_necessary

        self.handshake
      rescue Exception => error
        raise error
      end # post_init



      #
      # EventMachine receives data in chunks, sometimes those chunks are smaller
      # than the size of AMQP frame. That's why you need to add some kind of buffer.
      #
      def receive_data(chunk)
        @chunk_buffer << chunk
        while frame = get_next_frame
          self.receive_frame(AMQ::Client::Framing::String::Frame.decode(frame))
        end
      end

      def unbind
        closing!

        @tcp_connection_established = false

        @connections.each { |c| c.on_connection_interruption }
        @disconnection_deferrable.succeed

        closed!

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



      def on_connection(&block)
        @connection_deferrable.callback(&block)
      end # on_connection(&block)

      # called by AMQ::Client::Connection after we receive connection.open-ok.
      def connection_successful
        @connection_deferrable.succeed
      end # connection_successful


      def on_open(&block)
        @connection_opened_deferrable.callback(&block)
      end # on_open(&block)

      def open_successful
        @authenticating = false
        @connection_opened_deferrable.succeed

        opened!
      end # open_successful


      def on_disconnection(&block)
        @disconnection_deferrable.callback(&block)
      end # on_disconnection(&block)

      # called by AMQ::Client::Connection after we receive connection.close-ok.
      def disconnection_successful
        @disconnection_deferrable.succeed

        self.close_connection
        closed!
      end # disconnection_successful



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
