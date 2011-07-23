# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default, :test)

require 'amq/client'

#
# Ruby version-specific
#

require "effin_utf8"

case RUBY_VERSION
when "1.8.7" then
  class Array
    alias sample choice
  end
when /^1.9/ then
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

RSpec.configure do |c|
  c.filter_run_excluding :nojruby => true if RUBY_PLATFORM =~ /java/
end


module PlatformDetection
  def mri?
    !defined?(RUBY_ENGINE) || (defined?(RUBY_ENGINE) && ("ruby" == RUBY_ENGINE))
  end
end