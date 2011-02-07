# encoding: utf-8

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

      attr_reader :server_properties
      def initialize(client, server_properties)
        @server_properties = server_properties
        super(client)
      end

      def start_ok
        @client.send Protocol::Connection::StartOk.encode(CLIENT_PROPERTIES, "PLAIN", "", "en_GB")
      end

      def tune_ok(method)
        channel_max = method.channel_max
        frame_max   = method.frame_max
        heartbeat   = method.heartbeat

        @client.send Connection::TuneOk.encode(channel_max, frame_max, heartbeat)
      end

      def open
        @client.send Connection::Open.encode("/")
      end

      def close(method)
        # TODO: use proper exception class, provide protocol class (we know method.class_id and method.method_id) as well!
        raise RuntimeError.new(method.reply_text)
      end

      # === Handlers ===
      self.handle(Protocol::Connection::Start) do |client, method|
        client.connection = AMQ::Client::Connection.new(client, method.server_properties)
        client.connection.start_ok
        puts "StartOk" ###
      end

      self.handle(Protocol::Connection::Tune) do |client, method|
        puts "Tune!" ###

        client.connection.tune_ok(method)
        client.connection.open

        puts "AMQP initialized!" ####
      end

      self.handle(Protocol::Connection::Close) do |client, method|
        client.connection.close(method)
      end
    end
  end
end
