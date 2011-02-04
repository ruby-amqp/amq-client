# encoding: utf-8

# This will be probably used by all the async libraries like EventMachine.
# It expects the whole frame as one string, so if library of your choice
# gives you input chunk-by-chunk, you'll need to have something like this:
#
# class Client
#   include EventMachine::Deferrable
#
#   def receive_data(chunk)
#     if @payload.nil?
#       self.decode_from_string(chunk[0..6])
#       @payload = ""
#     elsif @payload && chunk[-1] != FINAL_OCTET
#       @payload += chunk
#       @size += chunk.bytesize
#     else
#       check_size(@size, @payload.bytesize)
#       Frame.decode(@payload) # we need the whole payload
#       @size, @payload = nil
#     end
#   end
#
#   NOTE: the client should also implement waiting for another frames, in case that some header/body frames are expected.
# end

module AMQ
  module Client


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



    module StringAdapter
      def decode(string)
        header = string[0..6]
        type, channel, size = self.decode_header(header)
        data = string[7..-1]
        payload, frame_end = data[0..-2], data[-1].force_encoding(FINAL_OCTET.encoding)

        # 1) the size is miscalculated
        if payload.bytesize != size
          raise BadLengthError.new(size, payload.bytesize)
        end

        # 2) the size is OK, but the string doesn't end with FINAL_OCTET
        raise NoFinalOctetError.new if frame_end != FINAL_OCTET

        self.new(type, payload, channel)
      end
    end
  end
end
