# encoding: utf-8

require "amq/client/exceptions"
require "amq/client/adapter"

module AMQ
  module Client
    def self.register_io_adapter(adapter)
      load_amq_protocol
      AMQ::Protocol::Frame.extend(adapter) # FIXME: what if one want to use more adapters in the same app? I. e. during the rewrite ...
    end

    def self.load_amq_protocol(path = "client")
      require "amq/protocol/#{path}"
    rescue LoadError => exception
      if exception.message.match("amq/protocol")
        raise LoadError.new("You have to install amq-protocol library first!")
      else
        raise exception
      end
    end
  end
end
