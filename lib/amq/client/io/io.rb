# encoding: utf-8

module AMQ
  module Client
    module IOAdapter
      def decode(io)
        header = readable.read(7)
        type, channel, size = self.decode_header(header)
        data = readable.read(size + 1)
        payload, frame_end = data[0..-2], data[-1]
        raise RuntimeError.new("Frame doesn't end with #{FINAL_OCTET} as it must, which means the size is miscalculated.") unless frame_end == FINAL_OCTET # TODO: this will hang if the size is bigger than expected or it'll leave there some chars -> make it more error-proof
        self.new(type, payload, channel)
      end
    end
  end
end
