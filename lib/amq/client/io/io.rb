# encoding: utf-8

module AMQ
  module Client
    FINAL_OCTET = AMQ::Protocol::Frame::FINAL_OCTET

    # TODO: currently this is copy/pasted
    FINAL_OCTET = AMQ::Protocol::Frame::FINAL_OCTET

    class InconsistentDataError < StandardError
    end

    class NoFinalOctetError < InconsistentDataError
      def initialize
        super("Frame doesn't end with #{FINAL_OCTET} as it must, which means the size is miscalculated.")
      end
    end

    class BadLengthError < InconsistentDataError
      def initialize(expected_length, actual_length)
        super("Frame payload should be #{expected_length} long, but it's #{actual_length} long.")
      end
    end

    module IOAdapter
      def decode(io)
        header = io.read(7)
        type, channel, size = self.decode_header(header)
        data = io.read(size + 1)
        payload, frame_end = data[0..-2], data[-1]
        # TODO: this will hang if the size is bigger than expected or it'll leave there some chars -> make it more error-proof:
        raise NoFinalOctetError.new if frame_end != FINAL_OCTET
        self.new(type, payload, channel)
      end
    end
  end
end
