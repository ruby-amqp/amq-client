# encoding: utf-8

require "amq/client/version"
require "amq/client/exceptions"
require "amq/client/adapter"
require "amq/client/channel"
require "amq/client/exchange"
require "amq/client/queue"

begin
  require "amq/protocol/client"
rescue LoadError => exception
  if exception.message.match("amq/protocol")
    raise LoadError.new("You have to install amq-protocol library first!")
  else
    raise exception
  end
end
