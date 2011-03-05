require "bundler"

Bundler.setup
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "amq/client/adapters/event_machine"
require "amq/client/amqp/queue"
require "amq/client/amqp/exchange"


if RUBY_VERSION.to_s =~ /^1.9/
  puts "Encoding.default_internal was #{Encoding.default_internal || 'not set'}, switching to UTF8"
  Encoding.default_internal = Encoding::UTF_8

  puts "Encoding.default_external was #{Encoding.default_internal || 'not set'}, switching to UTF8"
  Encoding.default_external = Encoding::UTF_8
end
