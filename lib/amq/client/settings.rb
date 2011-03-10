# encoding: utf-8

require "amq/protocol/client" # TODO: "amq/protocol/constants"

module AMQ
  module Client
    # @see AMQ::Client::Settings.configure
    module Settings
      # Default connection settings used by AMQ clients
      #
      # @see AMQ::Client::Settings.configure
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

      # Merges given configuration parameters with defaults and returns
      # the result.
      #
      # @param [Hash] Configuration parameters to use.
      #
      # @option settings [String] :host ("127.0.0.1") Hostname AMQ broker runs on.
      # @option settings [String] :port (5672) Port AMQ broker listens on.
      # @option settings [String] :vhost ("/") Virtual host to use.
      # @option settings [String] :user ("guest") Username to use for authentication.
      # @option settings [String] :pass ("guest") Password to use for authentication.
      # @option settings [String] :ssl (false) Should be use TLS (SSL) for connection?
      # @option settings [String] :timeout (nil) Connection timeout.
      # @option settings [String] :logging (false) Turns logging on or off.
      # @option settings [String] :broker (nil) Broker name (use if you intend to use broker-specific features).
      # @option settings [Fixnum] :frame_max (131072) Maximum frame size to use. If broker cannot support frames this large, broker's maximum value will be used instead.
      #
      # @return [Hash] Merged configuration parameters.
      def self.configure(settings = nil)
        case settings
        when Hash then
          if password = settings.delete(:username)
            settings[:user] ||= password
          end

          if password = settings.delete(:password)
            settings[:pass] ||= password
          end


          self.default.merge(settings)
        when String then
          settings = self.parse_amqp_url(settings)
          self.default.merge(settings)
        when NilClass then
          self.default
        end
      end

      def self.parse_amqp_url(string)
        raise NotImplementedError.new
      end
    end
  end
end
