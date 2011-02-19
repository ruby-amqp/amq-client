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
    # @see Section 2.3.5 in {http://bit.ly/hw2ELX AMQP 0.9.1 specification}
    class NoFinalOctetError < InconsistentDataError
      def initialize
        super("Frame doesn't end with #{AMQ::Protocol::Frame::FINAL_OCTET} as it must, which means the size is miscalculated.")
      end
    end

    # Raised by adapters when actual frame payload size in bytes is not equal
    # to the size specified in that frame's header.
    # This suggest that there is a bug in adapter or AMQ broker implementation.
    #
    # @see Section 2.3.5 in {http://bit.ly/hw2ELX AMQP 0.9.1 specification}
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
      class IncompatibleLoggerError < StandardError
        def initialize(required_methods)
          super("Logger has to respond to the following methods: #{required_methods.inspect}")
        end
      end
    end # Logging
  end # Client
end # AMQ
