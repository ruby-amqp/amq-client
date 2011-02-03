# encoding: utf-8

# $LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "bundler"

Bundler.setup
Bundler.require(:default, :test)

class TestIoAdapter
  attr_accessor :type, :payload, :channel
  def initialize(type, payload, channel)
    @type, @payload, @channel = type, payload, channel
  end
end
