# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default, :test)

#
# Ruby version-specific
#

case RUBY_VERSION
when "1.8.7" then
  class Array
    alias sample choice
  end
when /^1.9/ then
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end