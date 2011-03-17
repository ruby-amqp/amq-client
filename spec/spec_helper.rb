# encoding: utf-8

require "bundler"

Bundler.setup
Bundler.require(:default, :test)

#
# Ruby version-specific
#

case RUBY_VERSION
when "1.8.7" then
  module ArrayExtensions
    def sample
      self.choice
    end # sample
  end

  class Array
    include ArrayExtensions
  end
when "1.8.6" then
  raise "Ruby 1.8.6 is not supported. Sorry, pal. Time to move on beyond One True Ruby. Yes, time flies by."
when /^1.9/ then
  puts "Encoding.default_internal was #{Encoding.default_internal || 'not set'}, switching to #{Encoding::UTF_8}"
  Encoding.default_internal = Encoding::UTF_8

  puts "Encoding.default_external was #{Encoding.default_internal || 'not set'}, switching to #{Encoding::UTF_8}"
  Encoding.default_external = Encoding::UTF_8
end