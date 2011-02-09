# encoding: utf-8

require "ostruct"
require "spec_helper"
require "amq/client"

describe AMQ::Client do
  it "should have VERSION" do
    AMQ::Client::const_defined?(:VERSION).should be_true
  end
end
