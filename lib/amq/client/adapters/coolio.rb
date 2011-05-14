# encoding: utf-8

# http://coolio.github.com

require "cool.io"
require "amq/client"
require "amq/client/framing/string/frame"

module AMQ
  module Client
    #
    # CoolioClient is a drop-in replacement for EventMachineClient, if you prefer
    # cool.io style.
    #
    class CoolioClient
      #
      # Cool.io socket delegates most of its operations to the parent adapter.
      # Thus, 99.9% of the time you don't need to deal with this class.
      #
      # @api private
      # @private
      class Socket < ::Coolio::TCPSocket
        attr_accessor :adapter

        # Connects to given host/port and sets parent adapter.
        #
        # @param [CoolioClient]
        # @param [String]
        # @param [Fixnum]
        def self.connect(adapter, host, port)
          socket = super(host, port)
          socket.adapter = adapter
          socket
        end

        # Triggers socket_connect callback
        def on_connect
          #puts "On connect"
          adapter.socket_connected
        end

        # Triggers on_read callback
        def on_read(data)
          # puts "Received data"
          # puts_data(data)
          adapter.receive_data(data)
        end

        # Triggers socket_disconnect callback
        def on_close
          adapter.socket_disconnected
        end

        # Triggers tcp_connection_failed callback
        def on_connect_failed
          adapter.tcp_connection_failed
        end

        # Sends raw data through the socket
        #
        # param [String] Binary data
        def send_raw(data)
          # puts "Sending data"
          # puts_data(data)
          write(data)
        end

        protected
        # Debugging routine
        def puts_data(data)
          puts "    As string:     #{data.inspect}"
          puts "    As byte array: #{data.bytes.to_a.inspect}"
        end
      end

      #
      # Behaviors
      #

      include AMQ::Client::Adapter
      include AMQ::Client::CallbacksMixin

      self.sync = false

      #
      # API
      #

      # Cool.io socket for multiplexing et al.
      #
      # @private
      attr_accessor :socket

      # Hash with available callbacks
      attr_accessor :callbacks

      # AMQP connections
      #
      # @see AMQ::Client::Connection
      attr_accessor :connections

      # Creates a socket and attaches it to cool.io default loop.
      #
      # Called from CoolioClient.connect
      #
      # @see AMQ::Client::Adapter::ClassMethods#connect
      # @param [Hash] connection settings
      # @api private
      def establish_connection(settings)
        socket = Socket.connect(self, settings[:host], settings[:port])
        socket.attach(Cool.io::Loop.default)
        self.socket = socket
      end

      # Registers on_open callback
      # @see #on_open
      # @api private
      def register_connection_callback(&block)
        self.on_open(&block)
      end

      # Performs basic initialization. Do not use this method directly, use
      # CoolioClient.connect instead
      #
      # @see AMQ::Client::Adapter::ClassMethods#connect
      # @api private
      def initialize
        # Be careful with default values for #ruby hashes: h = Hash.new(Array.new); h[:key] ||= 1
        # won't assign anything to :key. MK.
        @callbacks   = {}
        @connections = []
        super
        if settings[:on_tcp_connection_failure]
          on_tcp_connection_failure(&settings.delete(:on_tcp_connection_failure))
        end
      end

      # Sets a callback for successful connection (after we receive open-ok)
      #
      # @api public
      def on_open(&block)
        define_callback :connect, &block
      end
      alias on_connection on_open

      # Sets a callback for disconnection (as in client-side disconnection)
      #
      # @api public
      def on_closed(&block)
        define_callback :disconnect, &block
      end
      alias on_disconnection on_closed

      # Sets a callback for tcp connection failure (as in can't make initial connection)
      def on_tcp_connection_failure(&block)
        define_callback :tcp_connection_failure, &block
      end


      # Called by AMQ::Client::Connection after we receive connection.open-ok.
      #
      # @api private
      def connection_successful
        @authenticating = false
        opened!

        exec_callback_yielding_self(:connect)
      end


      # Called by AMQ::Client::Connection after we receive connection.close-ok.
      #
      # @api private
      def disconnection_successful
        exec_callback_yielding_self(:disconnect)
        close_connection
        closed!
      end


      # Called by Socket if it could not connect.
      #
      # @api private
      def tcp_connection_failed
        if has_callback?(:tcp_connection_failure)
          exec_callback_yielding_self(:tcp_connection_failure)
        else
          raise self.class.tcp_connection_failure_exception_class.new(settings)
        end
      end # tcp_connection_failed

      # Called when socket is connected but before handshake is done
      #
      # @api private
      def socket_connected
        post_init
      end

      # Called after socket is closed
      #
      # @api private
      def socket_disconnected
      end

      # Sends raw data through the socket
      #
      # @param [String] binary data
      # @api private
      def send_raw(data)
        socket.send_raw data
      end

      # The story about the buffering is kinda similar to EventMachine,
      # you keep receiving more than one frame in a single packet.
      #
      # @param [String] chunk with binary data received. It could be one frame,
      #   more than one frame or less than one frame.
      # @api private
      def receive_data(chunk)
        @chunk_buffer << chunk
        while frame = get_next_frame
          receive_frame(AMQ::Client::Framing::String::Frame.decode(frame))
        end
      end

      # Closes the socket.
      #
      # @api private
      def close_connection
        @socket.close
      end

      # Returns class used for tcp connection failures.
      #
      # @api private
      def self.tcp_connection_failure_exception_class
        AMQ::Client::TCPConnectionFailed
      end # self.tcp_connection_failure_exception_class

      protected

      # @api private
      def post_init
        reset
        handshake
      end

      # @api private
      def reset
        @chunk_buffer = ""
      end

      # Returns next frame from buffer whenever possible
      #
      # @api private
      def get_next_frame
        return nil unless @chunk_buffer.size > 7 # otherwise, cannot read the length
        # octet + short
        offset = 1 + 2
        # length
        payload_length = @chunk_buffer[offset, 4].unpack('N')[0]
        # 4 bytes for long payload length, 1 byte final octet
        frame_length = offset + 4 + payload_length + 1
        if frame_length <= @chunk_buffer.size
          @chunk_buffer.slice!(0, frame_length)
        else
          nil
        end
      end
    end
  end
end
