# encoding: utf-8

# http://coolio.github.com

require "cool.io"
require "amq/client"

require "amq/client/io/string"

module AMQ
  module Client
    class Coolio
      class Socket < ::Coolio::TCPSocket
        attr_accessor :adapter

        def self.connect(adapter, host, port)
          socket = super(host, port)
          socket.adapter = adapter
          socket
        end

        def on_connect
          #puts "On connect"
          adapter.on_connect
        end

        def on_read(data)
          # puts "Received data"
          # puts_data(data)
          adapter.on_read(data)
        end

        def on_close
          puts "Cool.io hit EOF"
        end

        protected
        def puts_data(data)
          puts "    As string:     #{data.inspect}"
          puts "    As byte array: #{data.bytes.to_a.inspect}"
        end
      end

      # Behaviors
      include AMQ::Client::Adapter

      self.sync = false

      # API
      attr_accessor :socket
      attr_accessor :callbacks

      class <<self
        def connect(settings, &block)
          settings        = self.settings.merge(settings)
          host, port      = settings[:host], settings[:port]
          instance        = new
          socket          = Socket.connect(instance, settings[:host], settings[:port])
          socket.attach Cool.io::Loop.default
          instance.socket = socket
          instance.on_connection(&block)
          instance
        end

      end

      def initialize
        @callbacks = {}
        super
      end

      # sets a callback for connection
      def on_connection(&block)
        @callbacks[:connect] = block
      end

      # sets a callback for disconnection
      def on_disconnection(&block)
        @callbacks[:disconnect] = block
      end

      # triggered when socket is connected but before handshake is done
      def on_connect
        post_init
      end


      # triggered after socket is disconnected
      def on_disconnect
      end

      def post_init
        reset
        handshake
      end

      def send_raw(data)
        puts "Sending raw: #{[data, data.bytes.to_a].inspect}"
        socket.write data
      end

      # The story about the buffering is kinda similar to EventMachine,
      # you keep receiving more than one frame in a single packet.
      def on_read(chunk)
        @chunk_buffer << chunk
        while frame = get_next_frame
          receive_frame(AMQ::Client::StringAdapter::Frame.decode(frame))
        end
      end

      # called by AMQ::Client::Connection after we receive connection.open-ok.
      def connection_successful
        @callbacks[:connect].call(self) if @callbacks[:connect]
      end

      # called by AMQ::Client::Connection after we receive connection.close-ok.
      def disconnection_successful
        @callbacks[:disconnect].call(self) if @callbacks[:disconnect]
      end

      protected
      def reset
        @chunk_buffer = ""
      end

      def encode_credentials(username, password)
        "\0guest\0guest"
      end # encode_credentials(username, password)

      def get_next_frame
        if pos = @chunk_buffer.index(AMQ::Protocol::Frame::FINAL_OCTET)
          @chunk_buffer.slice!(0, pos + 1)
        end
      end
    end
  end
end
