# encoding: utf-8

module AMQ
  module Client
    extend self

    def register_io_adapter(adapter)
      load_amq_protocol
      AMQ::Protocol::Frame.extend(adapter)
    end

    def load_amq_protocol
      require "amq/protocol/client"
    rescue LoadError => exception
      if exception.message.match("amq/protocol/client")
        raise LoadError.new("You have to install amq-protocol library first!")
      else
        raise exception
      end
    end
  end
end
