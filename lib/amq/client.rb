# encoding: utf-8
__dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))

$:.unshift(__dir) unless $:.include?(__dir)


module AMQ
  module Client
    VERSION = "0.0.1".freeze
  end
end

require "amq/client/exceptions"
require "amq/client/adapter"

begin
  require "amq/protocol/client" # TODO: what about server?
rescue LoadError => exception
  if exception.message.match("amq/protocol")
    raise LoadError.new("You have to install amq-protocol library first!")
  else
    raise exception
  end
end
