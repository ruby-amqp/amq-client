# encoding: utf-8

require "amq/client"
require "amq/client/amqp/channel"
require "amq/client/amqp/exchange"
require "amq/client/io/string"

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
        settings          = AMQ::Client::Settings.configure(settings)
        instance          = EM.connect(settings[:host], settings[:port], self, settings)

        if block.nil?
          instance
        else
          # delay calling block we were given till after we receive
          # connection.open-ok. Connection will notify us when
          # that happens.
          instance.on_connection do
            block.call(instance)
          end
        end
      end


      attr_reader :connections


      def initialize(*args)
        super(*args)

        # EventMachine::Connection's and Adapter's constructors arity
        # make it easier to use *args. MK.
        @settings                 = args.first
        @connections              = Array.new

        @chunk_buffer             = ""
        @connection_deferrable    = Deferrable.new
        @disconnection_deferrable = Deferrable.new

        @authenticating           = false

        # succeeds when connection is open, that is, vhost is selected
        # and client is given green light to proceed.
        @connection_opened_deferrable = Deferrable.new
      end # initialize(*args)


      def establish_connection(settings)
        # an intentional no-op
      end

      alias send_raw send_data


      def authenticating?
        @authenticating
      end # authenticating?



      #
      # Implementation
      #

      def post_init
        begin
          reset

          self.handshake
        rescue Exception => e
          raise e
        end
      end # post_init

      #
      # EventMachine receives data in chunks, sometimes those chunks are smaller
      # than the size of AMQP frame. That's why you need to add some kind of buffer.
      #
      def receive_data(chunk)
        @chunk_buffer << chunk
        while frame = next_frame
          self.receive_frame(AMQ::Client::StringAdapter::Frame.decode(frame))
        end
      end

      def unbind
        # since AMQP spec dictates that authentication failure is a protocol exception
        # and protocol exceptions result in connection closure, check whether we are
        # in the authentication stage. If so, it is likely to signal an authentication
        # issue. Java client behaves the same way. MK.
        raise PossibleAuthenticationFailureError.new(@settings) if authenticating?

        @connections.each { |c| c.on_connection_interruption }
        @disconnection_deferrable.succeed
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
      end # open_successful


      def on_disconnection(&block)
        @disconnection_deferrable.callback(&block)
      end # on_disconnection(&block)

      # called by AMQ::Client::Connection after we receive connection.close-ok.
      def disconnection_successful
        @disconnection_deferrable.succeed

        self.close_connection
      end # disconnection_successful


      protected

      def handshake(mechanism = "PLAIN", response = nil, locale = "en_GB")
        username = @settings[:user] || @settings[:username]
        password = @settings[:pass] || @settings[:password]

        self.logger.info "[authentication] Credentials are #{username}/#{'*' * password.bytesize}"

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

      def next_frame
        if pos = @chunk_buffer.index(AMQ::Protocol::Frame::FINAL_OCTET)
          @chunk_buffer.slice!(0, pos + 1)
        end
      end
    end # EventMachineClient
  end # Client
end # AMQ
