# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default)

$LOAD_PATH.unshift(File.expand_path("../../../lib", __FILE__))

require "amq/client/adapters/coolio"
require "amq/client/queue"
require "amq/client/exchange"


if RUBY_VERSION.to_s =~ /^1.9/
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end


def amq_client_example(description = "", &block)
  AMQ::Client::CoolioClient.connect(:port => 5672, :vhost => "amq_client_testbed") do |client|
    begin
      puts
      puts
      puts "=============> #{description}"

      block.call(client)
    rescue Interrupt
      warn "Manually interrupted, terminating ..."
    rescue Exception => exception
      STDERR.puts "\n\e[1;31m[#{exception.class}] #{exception.message}\e[0m"
      exception.backtrace.each do |line|
        line = "\e[0;36m#{line}\e[0m" if line.match(Regexp::quote(File.basename(__FILE__)))
        STDERR.puts "  - " + line
      end
    end
  end
  
  cool.io.run
end
