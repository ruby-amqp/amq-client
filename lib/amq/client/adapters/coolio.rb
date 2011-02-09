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

require "amq/client/io/string"

module AMQ
  module Client
    class CoolioClient < AMQ::Client::Adapter
      self.sync = false

      def establish_connection(settings)
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

      def disconnect
      end

      def send_raw(data)
      end
    end
  end
end
