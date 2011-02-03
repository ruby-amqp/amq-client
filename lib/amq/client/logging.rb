# encoding: utf-8

# You can use arbitrary logger which responds to #debug, #info, #error and #fatal methods, so for example the logger from standard library will work fine:
#
# require "logger"
#
# AMQ::Client.logging = true
# AMQ::Client.logger  = Logger.new(STDERR)


# AMQ::Client
module AMQ
  module Client
    module Logging
      REQUIRED_METHODS ||= begin
        [:debug, :info, :error, :fatal]
      end

      def debug(message)
        log(:debug, message)
      end

      def info(message)
        log(:info, message)
      end

      def error(message)
        log(:error, message)
      end

      def fatal(message)
        log(:fatal, message)
      end

      protected
      def log(method, message)
        if AMQ::Client.logging
          AMQ::Client.logger.send(method, message)
          message
        end
      end
    end
  end
end
