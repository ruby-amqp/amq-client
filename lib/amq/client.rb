# encoding: utf-8

begin
  require "amq/protocol/client"
rescue LoadError => exception
  if exception.message.match("amq/protocol")
    raise LoadError.new("You must install amq-protocol in order to use amq-client")
  else
    raise exception
  end
end

require "amq/client/version"
require "amq/client/exceptions"
require "amq/client/adapter"
