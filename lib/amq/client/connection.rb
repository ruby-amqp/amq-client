# encoding: utf-8

require "amq/client"
require "amq/client/entity"

module AMQ
  module Client
    # AMQP connection object handles various connection lifecycle events
    # (for example, Connection.Start-Ok, Connection.Tune-Ok and Connection.Close
    # methods)
    #
    # AMQP connection has multiple channels accessible via {Connection#channels} reader.
    class Connection < Entity

      #
      # Behaviors
      #

      include StatusMixin


      #
      # API
      #

      # TODO: make it possible to override these from, say, amqp gem or bunny
      CLIENT_PROPERTIES = {
        :platform => ::RUBY_DESCRIPTION,
        :product  => "AMQ Client",
        :version  => AMQ::Client::VERSION,
        :homepage => "https://github.com/ruby-amqp/amq-client"
      }.freeze

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

      # Security response data.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Sections 1.4.2.2 and 1.4.2.4.1)
      attr_reader :response

      # The locale defines the language in which the server will send reply texts.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.2)
      attr_reader :locale

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

      # The delay, in seconds, of the connection heartbeat that the server wants.
      # Zero means the server does not want a heartbeat.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.5.3)
      attr_accessor :heartbeat_interval

      attr_reader :known_hosts



      # @api public
      def initialize(client, mechanism, response, locale, client_properties = nil)
        @mechanism         = mechanism
        @response          = response
        @locale            = locale

        @channels          = Hash.new
        @client_properties = client_properties || {
          :platform    => "Ruby #{RUBY_VERSION}",
          :product     => "AMQ Client",
          :information => "http://github.com/ruby-amqp/amq-client",
          :version     => AMQ::Client::VERSION
        }

        reset_state!

        super(client)

        @client.connections.push(self)

        # Default errback.
        # You might want to override it, otherwise it'll
        # crash your program. It's the expected behaviour
        # if it's a synchronous one, but not if you use
        # some kind of event loop like EventMachine etc.
        self.define_callback(:close) { |exception| raise(exception) }
      end

      # @api public
      def settings
        @client.settings
      end # settings


      #
      # Connection class methods
      #


      # Sends connection.open to the server.
      #
      # @api public
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.7)
      def open(vhost = "/")
        @client.send Protocol::Connection::Open.encode(vhost)
      end


      # Sends connection.close to the server.
      #
      # @api public
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.9)
      def close(reply_code = 200, reply_text = "Goodbye", class_id = 0, method_id = 0)
        @client.send Protocol::Connection::Close.encode(reply_code, reply_text, class_id, method_id)
        closing!
      end

      # @api public
      def reset_state!
      end # reset_state!



      #
      # Implementation
      #


      # Handles Connection.Start.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.1.)
      def start_ok(method)
        @server_properties = method.server_properties

        # It's not clear whether we should transition to :opening state here
        # or in #open but in case authentication fails, it would be strange to have
        # @status undefined. So lets do this. MK.
        opening!

        @client.send Protocol::Connection::StartOk.encode(@client_properties, @mechanism, @response, @locale)
      end


      # Handles Connection.Open-Ok.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.8.)
      def handle_open_ok(method)
        @known_hosts = method.known_hosts

        opened!
        # async adapters need this callback to proceed with
        # Adapter.connect block evaluation
        @client.connection_successful if @client.respond_to?(:connection_successful)
      end

      # Handles Connection.Tune-Ok.
      #
      # @api plugin
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.6)
      def handle_tune(method)
        @channel_max        = method.channel_max
        @frame_max          = method.frame_max
        @heartbeat_interval = @client.heartbeat_interval || method.heartbeat

        @client.send Protocol::Connection::TuneOk.encode(@channel_max, [settings[:frame_max], @frame_max].min, @heartbeat_interval)
      end # handle_tune(method)


      # Handles Connection.Close.
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
        @client.disconnection_successful
      end # handle_close_ok(method)

      # @api plugin
      def handle_connection_interruption
        @channels.each { |n, c| c.handle_connection_interruption }
      end # handle_connection_interruption



      #
      # Handlers
      #

      self.handle(Protocol::Connection::Start) do |client, frame|
        client.connection.start_ok(frame.decode_payload)
      end

      self.handle(Protocol::Connection::Tune) do |client, frame|
        client.connection.handle_tune(frame.decode_payload)

        client.connection.open(client.settings[:vhost] || "/")
        client.open_successful
      end

      self.handle(Protocol::Connection::OpenOk) do |client, frame|
        client.connection.handle_open_ok(frame.decode_payload)
      end

      self.handle(Protocol::Connection::Close) do |client, frame|
        client.connection.handle_close(frame.decode_payload)
      end

      self.handle(Protocol::Connection::CloseOk) do |client, frame|
        client.connection.handle_close_ok(frame.decode_payload)
      end


    end # Connection
  end # Client
end # AMQ
