# encoding: utf-8

require "socket"
require "amq/client"

AMQ.register_io_adapter(:io)

module AMQ
  class SocketClient < Client
    def self.__connect__(settings) # co tohle udelat instancni #connect? treba kvuli pristupnosti @vars
      # NOTE: this doesn't work with "localhost", I don't know why:
      settings[:host] = "127.0.0.1" if settings[:host] == "localhost"
      @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      sockaddr = Socket.pack_sockaddr_in(settings[:port], settings[:host])

      @socket.connect(sockaddr)
    rescue Errno::ECONNREFUSED
      abort "Don't forget to start an AMQP broker first!"
    ensure
      @socket.close if @socket && @socket.connected?
    end
  end
end
