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
# end

module AMQ
  module Client
    module StringAdapter
      def decode(string)
        header = string[0..6]
        type, channel, size = self.decode_header(header)
        data = string[6..-1]
        payload, frame_end = data[0..-2], data[-1]
        raise RuntimeError.new("Frame doesn't end with #{FINAL_OCTET} as it must, which means the size is miscalculated.") unless frame_end == FINAL_OCTET # TODO: rewrite, we have both the actual size as well as the supposed size
        self.new(type, payload, channel)
      end
    end
  end
end
