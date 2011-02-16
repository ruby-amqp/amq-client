# encoding: utf-8

require "amq/client/exceptions"

module AMQ
  module Client
    module IOAdapter
      class Frame < AMQ::Protocol::Frame
        def self.decode(io)
          header = io.read(7)
          type, channel, size = self.decode_header(header)
          data = io.read(size + 1)
          if RUBY_VERSION < "1.9"
            # The m flag's important, the data often contains "\n":
            data.match(/^(.+)(.)$/m)
            payload, frame_end = $1, $2
          else
            payload, frame_end = data[0..-2], data[-1]
          end
          # TODO: this will hang if the size is bigger than expected or it'll leave there some chars -> make it more error-proof:
          # BTW: socket#eof?
          raise NoFinalOctetError.new if frame_end != AMQ::Protocol::Frame::FINAL_OCTET
          self.new(type, payload, channel)
        end
      end
    end
  end
end

class AMQ::Protocol::Frame
  def final?
    true ####### HACK for testing, implement & move to amq-protocol!
  end
end
