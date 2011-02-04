# encoding: utf-8

require "amq/protocol/client" # TODO: "amq/protocol/constants"

module AMQ
  module Client
    module Settings
      def self.default
        {
          # server
          :host  => "127.0.0.1",
          :port  => AMQ::Protocol::DEFAULT_PORT,

          # login
          :user  => "guest",
          :pass  => "guest",
          :vhost => "/",

          # connection timeout
          :timeout => nil,

          # logging
          :logging => false,

          # ssl
          :ssl => false,

          # broker
          # if you want to load broker-specific extensions
          :broker => nil
        }
      end

      def self.configure(settings = nil)
        case settings
        when Hash
          self.default.merge(settings)
        when String
          settings = self.parse_amqp_url(settings)
          self.default.merge(settings)
        when NilClass
          self.default
        end
      end

      def self.parse_amqp_url(string)
        raise NotImplementedError.new
      end
    end
  end
end
