# encoding: utf-8

require "socket"
require "amq/client"
require "amq/client/framing/io/frame"

module AMQ
  module Client
    class SocketClient

      #
      # Behaviors
      #

      include AMQ::Client::Adapter

      self.sync = true

      register_entity :channel,  AMQ::Client::Channel


      #
      # API
      #

      def establish_connection(settings)
        # NOTE: this doesn't work with "localhost", I don't know why:
        settings[:host] = "127.0.0.1" if settings[:host] == "localhost"
        @socket         = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        sockaddr        = Socket.pack_sockaddr_in(settings[:port], settings[:host])

        @socket.connect(sockaddr)
      rescue Errno::ECONNREFUSED => exception
        message = "Don't forget to start an AMQP broker first!\nThe original message: #{exception.message}"
        raise exception.class.new(message)
      rescue Exception => exception
        self.disconnect if self.connected?
        raise exception
      end

      def connection
        @socket
      end # connection

      def connected?
        @socket && !@socket.closed?
      end

      def close_connection
        @socket.close
      end

      def send_raw(data)
        @socket.write(data)
      end

      def receive
        frame = AMQ::Client::Framing::IO::Frame.decode(@socket)
        self.receive_frame(frame)
        frame
      end

      def receive_async
        # NOTE: this might work with Socket#eof? as well, it can be better ...
        # self.receive unless @socket.eof?

        @sockets ||= [@socket] # It'll be always only one socket, but we don't want to create many arrays, mind the GC!
        array = IO.select(@sockets, nil, nil, nil)
        array[0].each do |socket|
          res = self.receive
        end
        res
      end

      def read_until_receives(klass)
        if self.sync?
          until (frame = self.receive) && frame.is_a?(Protocol::MethodFrame) && frame.method_class == klass
            sleep 0.1
          end
        end
      end
    end
  end
end
