# encoding: utf-8

require "amq/client"
require "amq/client/amqp/channel"
require "amq/client/amqp/exchange"
require "amq/client/io/string"

require "eventmachine"

module AMQ
  module Client
    class EventMachineClient < EM::Connection

      #
      # Behaviors
      #

      include AMQ::Client::Adapter
      include EventMachine::Deferrable

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

        if block
          block.call(instance)

          instance.disconnect
        else
          instance
        end
      end




      def establish_connection(settings)
        # an intentional no-op
      end

      def handshake(mechanism = "PLAIN", response = "\0guest\0guest", locale = "en_GB")
        self.send_preamble

        self.connection = AMQ::Client::Connection.new(self, mechanism, response, locale)
        @connecting     = true
      end


      # Client interface

      alias disconnect close_connection
      alias send_raw   send_data

      def receive_data(chunk)
        puts "Got some data: #{chunk}"
      end

      def reset
        @size, @payload = 0, ""
        @frames = Array.new
      end


      #
      # Implementation
      #

      def post_init
        reset
        reset_state

        send_preamble

        # @connection = AMQ::Client::Connection.new(self, "PLAIN", self.encode_credentials(@settings[:user], @settings[:pass], @settings.fetch(:locale, "en_GB")))
      end # post_init

      def unbind
      end # unbind

      protected

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
