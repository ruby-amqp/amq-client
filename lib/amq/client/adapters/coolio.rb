# encoding: utf-8

# http://coolio.github.com

# === Example ===
# require "amq/client/adapters/coolio"
#
# AMQ.adapter(:coolio)
# queue = Queue.new("tasks")
# queue.consume do |headers, message|
#   puts "Task scheduled: #{message}"
# end
#
# cool.io.run

require "cool.io"
require "amq/client"

AMQ.register_io_adapter(:string)

module AMQ
  class CoolIoClient < Client
    def self.__connect__(settings)
      cool.io.connect(settings[:host], settings[:port]) do
        on_connect do
          puts "Connected to #{remote_host}:#{remote_port}"
          write "bounce this back to me"
        end

        on_close do
          puts "Disconnected from #{remote_host}:#{remote_port}"
        end

        on_read do |data|
          puts "Got: #{data}"
          close
        end

        on_resolve_failed do
          puts "Error: Couldn't resolve #{remote_host}"
        end

        on_connect_failed do
          puts "Error: Connection refused to #{remote_host}:#{remote_port}"
        end
      end
    end
  end
end
