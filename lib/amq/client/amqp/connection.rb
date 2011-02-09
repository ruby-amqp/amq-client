# encoding: utf-8

require "amq/client"
require "amq/client/entity"

module AMQ
  module Client
    class Connection < Entity
      CLIENT_PROPERTIES ||= {
        :platform => ::RUBY_DESCRIPTION,
        :product  => "AMQ Client",
        :version  => AMQ::Client::VERSION,
        :homepage => "https://github.com/ruby-amqp/amq-client"
      }

      attr_accessor :server_properties
      attr_reader :mechanism, :response, :locale
      attr_reader :channels
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

      def start_ok
        @client.send Protocol::Connection::StartOk.encode({}, self.mechanism, self.response, self.locale)
        # @client.send Protocol::Connection::StartOk.encode(CLIENT_PROPERTIES, self.mechanism, self.response, self.locale)
      end

      def tune_ok(method)
        channel_max = method.channel_max
        frame_max   = method.frame_max
        heartbeat   = method.heartbeat

        @client.send Protocol::Connection::TuneOk.encode(channel_max, frame_max, heartbeat)
      end

      def open
        @client.send Protocol::Connection::Open.encode("/")
      end

      attr_reader :known_hosts
      def handle_open_ok(method)
        @known_hosts = method.known_hosts
      end

      def handle_close(method)
        # TODO: use proper exception class, provide protocol class (we know method.class_id and method.method_id) as well!
        self.error RuntimeError.new(method.reply_text)
        @closed = true
      end

      def closed?
        @closed
      end

      def opened?
        ! self.closed?
      end

      def close(reply_code = 0, reply_text = "Bye!", class_id = 0, method_id = 0)
        @client.send Protocol::Connection::Close.encode(reply_code, reply_text, class_id, method_id)
      end

      # === Handlers ===
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
