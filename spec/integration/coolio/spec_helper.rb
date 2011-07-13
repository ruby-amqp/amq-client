# encoding: utf-8

begin
  require "amq/client/adapters/coolio"
rescue LoadError => e
  if RUBY_PLATFORM =~ /java/
    puts "WARNING: Cool.io specs will not run on jruby"
  else
    # reraise, cause unknown
    raise e
  end
end
require "amq/client/queue"
require "amq/client/exchange"
require "evented-spec"

case RUBY_VERSION
when "1.8.7" then
  class Array
    alias sample choice
  end
when /^1.9/ then
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

def coolio_amqp_connect(&block)
  coolio do
    AMQ::Client::CoolioClient.connect(:port => 5672, :vhost => "amq_client_testbed", :frame_max => 2**16-1, :heartbeat_interval => 1) do |client|
      yield client
    end
  end
end
