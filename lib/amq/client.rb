# encoding: utf-8

module AMQ
  module Client
    VERSION = "0.0.1".freeze
  end
end

require "amq/client/exceptions"
require "amq/client/adapter"

begin
  require "amq/protocol/client"
rescue LoadError => exception
  if exception.message.match("amq/protocol")
    raise LoadError.new("You have to install amq-protocol library first!")
  else
    raise exception
  end
end
