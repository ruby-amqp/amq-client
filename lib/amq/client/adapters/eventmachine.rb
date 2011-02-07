# encoding: utf-8

require "amq/client"

require "amq/client/io/string"
AMQ::Client.register_io_adapter(AMQ::Client::StringAdapter)

module AMQ
  class EventMachineClient < AMQ::Client::Adapter
    include EventMachine::Deferrable

    def establish_connection(settings)
    end

    def disconnect
    end

    def send_raw(data)
    end

    def initialize
      @frames, @size, @payload = Array.new, 0, ""
    end

    # Client interface
    def send(frame)
      self.send_data(frame.encode)
    end

    def receive_data(chunk)
      if @payload.nil?
        self.decode_from_string(chunk[0..6])
      elsif @payload && chunk[-1] != AMQ::Protocol::Frame::FINAL_OCTET
        @payload += chunk
        @size += chunk.bytesize
      else
        check_size(@size, @payload.bytesize)
        frame = AMQ::Protocol::Frame.decode(@payload)
        # Wait for header and body frames.
        if frame.expects_body? or @frames.first.expects_more?(@frames.length)
          receive_frame(@frame)
        else
          receive_frameset(@frames)
          reset
        end
      end
    end

    def reset
      @size, @payload = 0, ""
      @frames.clear
    end
  end
end
