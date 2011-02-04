# encoding: utf-8

module AMQ
  module Client
    # Adapters
    class InconsistentDataError < StandardError
    end

    class NoFinalOctetError < InconsistentDataError
      def initialize
        super("Frame doesn't end with #{AMQ::Protocol::Frame::FINAL_OCTET} as it must, which means the size is miscalculated.")
      end
    end

    class BadLengthError < InconsistentDataError
      def initialize(expected_length, actual_length)
        super("Frame payload should be #{expected_length} long, but it's #{actual_length} long.")
      end
    end


    # Client
    class MissingInterfaceMethodError < NotImplementedError
      def initialize(method_name)
        super("Method #{method_name} is supposed to be redefined ......")
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
          super("Logger has to provide the following methods: #{required_methods.inspect}")
        end
      end
    end
  end
end
