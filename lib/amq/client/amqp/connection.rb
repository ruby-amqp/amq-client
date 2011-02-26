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
      CLIENT_PROPERTIES = {
        :platform => ::RUBY_DESCRIPTION,
        :product  => "AMQ Client",
        :version  => AMQ::Client::VERSION,
        :homepage => "https://github.com/ruby-amqp/amq-client"
      }.freeze

      # Authentication mechanism used.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.1.3)
      attr_accessor :server_properties

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
      attr_accessor :heartbeat

      attr_reader :known_hosts


      #
      # API
      #

      def initialize(client, mechanism, response, locale)
        @mechanism, @response, @locale = mechanism, response, locale
        @channels = Hash.new
        super(client)

        # Default errback.
        # You might want to override it, otherwise it'll
        # crash your program. It's the expected behaviour
        # if it's a synchronous one, but not if you use
        # some kind of event loop like EventMachine etc.
        self.callbacks[:close] = Proc.new do |exception|
          raise exception
        end
      end


      #
      # Connection class methods
      #

      def start_ok
        @client.send Protocol::Connection::StartOk.encode({}, self.mechanism, self.response, self.locale)
      end

      def tune_ok(method)
        @channel_max = method.channel_max
        @frame_max   = method.frame_max
        @heartbeat   = method.heartbeat

        @client.send Protocol::Connection::TuneOk.encode(@channel_max, @frame_max, @heartbeat)
      end

      # Sends Connection.Open to the server.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.7)
      # @todo Do not hardcode vhost we send to the broker. {http://github.com/michaelklishin MK}.
      def open
        @client.send Protocol::Connection::Open.encode("/")
      end

      # Handles Connection.Open-Ok
      #

      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.4.2.8.)
      def handle_open_ok(method)
        @known_hosts = method.known_hosts
      end

      # Handles Connection.Close-Ok
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.5.2.6)
      def handle_close(method)
        # TODO: use proper exception class, provide protocol class (we know method.class_id and method.method_id) as well!
        self.error RuntimeError.new(method.reply_text)
        @closed = true
      end

      # @returns [Boolean] true if this connection is closed.
      def closed?
        @closed
      end

      # @returns [Boolean] true if this connection is open.
      def opened?
        !self.closed?
      end

      # Sends Connection.Close to the server.
      #
      # @see http://bit.ly/htCzCX AMQP 0.9.1 protocol documentation (Section 1.5.2.5)
      # @todo Set @closing, await for Connection.Close-Ok, currently not thread-safe. {http://github.com/michaelklishin MK}.
      def close(reply_code = 200, reply_text = "Goodbye", class_id = 0, method_id = 0)
        @client.send Protocol::Connection::Close.encode(reply_code, reply_text, class_id, method_id)
      end


      #
      # Handlers
      #

      self.handle(Protocol::Connection::Start) do |client, frame|
        method = frame.decode_payload
        client.connection.server_properties = method.server_properties
        client.connection.start_ok
      end

      self.handle(Protocol::Connection::Tune) do |client, frame|
        method = frame.decode_payload
        client.connection.tune_ok(method)
        client.connection.open
      end

      self.handle(Protocol::Connection::OpenOk) do |client, frame|
        method = frame.decode_payload
        client.connection.handle_open_ok(method)
      end

      self.handle(Protocol::Connection::Close) do |client, frame|
        method = frame.decode_payload
        client.connection.handle_close(method)
      end
    end
  end
end
