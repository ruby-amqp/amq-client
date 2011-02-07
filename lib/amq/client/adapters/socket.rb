# encoding: utf-8

require "socket"
require "amq/client"

require "amq/client/io/io"
AMQ::Client.register_io_adapter(AMQ::Client::IOAdapter)

module AMQ
  class SocketClient < AMQ::Client::Adapter
    def establish_connection(settings)
      # NOTE: this doesn't work with "localhost", I don't know why:
      settings[:host] = "127.0.0.1" if settings[:host] == "localhost"
      @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      sockaddr = Socket.pack_sockaddr_in(settings[:port], settings[:host])

      @socket.connect(sockaddr)
    rescue Errno::ECONNREFUSED
      abort "Don't forget to start an AMQP broker first!"
    rescue Exception
      @socket.close if @socket && ! @socket.closed?
    end

    def disconnect
      @socket.close
    end

    def send_raw(data)
      @socket.write(data)
    end
  end
end
