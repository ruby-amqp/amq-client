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

        instance          = EM.connect(settings[:host], settings[:port], self)
        instance.settings = settings

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


      #
      # API
      #

      def initialize(*args)
        super(*args)

        @connection_deferrable    = Deferrable.new
        @disconnection_deferrable = Deferrable.new
      end # initialize(*args)


      def establish_connection(settings)
        # an intentional no-op
      end

      alias send_raw   send_data

      def receive_data(chunk)
        frame  = AMQ::Client::StringAdapter::Frame.decode(chunk)
        method = frame.method_class

        self.receive_frame(frame)
      end



      def on_connection(&block)
        @connection_deferrable.callback(&block)
      end # on_connection(&block)

      # called by AMQ::Client::Connection after we receive connection.open-ok.
      def connection_successful
        @connection_deferrable.succeed
      end # connection_successful



      def on_disconnection(&block)
        @disconnection_deferrable.callback(&block)
      end # on_disconnection(&block)

      # called by AMQ::Client::Connection after we receive connection.close-ok.
      def disconnection_successful
        @disconnection_deferrable.succeed

        self.close_connection
      end # disconnection_successful



      #
      # Implementation
      #

      def post_init
        reset
        reset_state

        @connecting    = true

        self.handshake
      end # post_init

      def unbind
        puts "Unbound"
      end # unbind

      protected

      def handshake(mechanism = "PLAIN", response = "\0guest\0guest", locale = "en_GB")
        self.send_preamble

        self.connection = AMQ::Client::Connection.new(self, mechanism, response, locale)
        @connecting     = true
      end

      def reset
        @size, @payload = 0, ""
        @frames = Array.new
      end

      def reset_state
        @connecting    = false
        @disconnecting = false
      end # reset_state

      def encode_credentials(username, password)
        "\0guest\0guest"
      end # encode_credentials(username, password)
    end # EventMachineClient
  end # Client
end # AMQ
