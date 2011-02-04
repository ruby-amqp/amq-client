# encoding: utf-8

require "amq/client/logging"
require "amq/client/settings"
require "amq/client/exceptions"

module AMQ
  module Client
    # Settings
    def self.settings
      @settings ||= AMQ::Client::Settings.default
    end

    # Let's integrate logging.
    module Logging
      def self.logging
        AMQ::Client.logging
      end

      def self.logging=(boolean)
        AMQ::Client.logging = boolean
      end
    end

    def self.logger
      if self.logging
        @logger ||= begin
          require "logger"
          Logger.new(STDERR)
        end
      end
    end

    def self.logger=(logger)
      methods = AMQ::Client::Logging::REQUIRED_METHODS
      unless methods.all? { |method| logger.respond_to?(method) }
        raise AMQ::Client::Logging::IncompatibleLoggerError.new(methods)
      end

      @logger = logger
    end

    def self.logging
      @settings[:logging]
    end

    def self.logging=(boolean)
      @settings[:logging] = boolean
    end

    def self.register_io_adapter(adapter)
      load_amq_protocol
      AMQ::Protocol::Frame.extend(adapter) # FIXME: what if one want to use more adapters in the same app? I. e. during the rewrite ...
    end

    def self.load_amq_protocol(path = "client")
      require "amq/protocol/#{path}"
    rescue LoadError => exception
      if exception.message.match("amq/protocol")
        raise LoadError.new("You have to install amq-protocol library first!")
      else
        raise exception
      end
    end
  end
end
