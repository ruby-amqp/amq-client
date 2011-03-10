# encoding: utf-8

module AMQ
  module Client

    #
    # Adapters
    #

    # Base exception class for data consistency and framing errors.
    class InconsistentDataError < StandardError
    end

    # Raised by adapters when frame does not end with {final octet AMQ::Protocol::Frame::FINAL_OCTET}.
    # This suggest that there is a bug in adapter or AMQ broker implementation.
    #
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.3)
    class NoFinalOctetError < InconsistentDataError
      def initialize
        super("Frame doesn't end with #{AMQ::Protocol::Frame::FINAL_OCTET} as it must, which means the size is miscalculated.")
      end
    end

    # Raised by adapters when actual frame payload size in bytes is not equal
    # to the size specified in that frame's header.
    # This suggest that there is a bug in adapter or AMQ broker implementation.
    #
    # @see http://bit.ly/hw2ELX AMQP 0.9.1 specification (Section 2.3)
    class BadLengthError < InconsistentDataError
      def initialize(expected_length, actual_length)
        super("Frame payload should be #{expected_length} long, but it's #{actual_length} long.")
      end
    end

    #
    # Client
    #

    class MissingInterfaceMethodError < NotImplementedError
      def initialize(method_name)
        super("Method #{method_name} is supposed to be overriden by adapter")
      end
    end

    class MissingHandlerError < StandardError
      def initialize(frame)
        super("No callback registered for #{frame.method_class}")
      end
    end

    module Logging
      # Raised when logger object passed to {AMQ::Client::Adapter.logger=} does not
      # provide API it supposed to provide.
      #
      # @see AMQ::Client::Adapter.logger=
      class IncompatibleLoggerError < StandardError
        def initialize(required_methods)
          super("Logger has to respond to the following methods: #{required_methods.inspect}")
        end
      end
    end # Logging


    class PossibleAuthenticationFailureError < StandardError

      #
      # API
      #

      def initialize(settings)
        super("AMQP broker closed TCP connection before authentication succeeded: this usually means authentication failure due to misconfiguration. Settings are #{settings.inspect}")
      end # initialize(settings)
    end # PossibleAuthenticationFailureError
  end # Client
end # AMQ
