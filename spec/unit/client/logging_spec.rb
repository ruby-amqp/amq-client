# encoding: utf-8

require "spec_helper"

class TestLogger
  def log(message)
    message
  end

  alias_method :debug, :log
  alias_method :info,  :log
  alias_method :error, :log
  alias_method :fatal, :log
end

class LoggingTestClass
  attr_accessor :logging

  def client
    OpenStruct.new(:logger => TestLogger.new)
  end

  include AMQ::Client::Logging
end

describe AMQ::Client::Logging do
  # We have to use Kernel#load so extensions to the
  # Logging module from client.rb will be overridden.
  before(:all) do
    load "amq/client/logging.rb"

    AMQ::Client::Logging.logging = true
  end

  after(:all) do
    AMQ::Client::Logging.logging = false
  end

  context "including to an incompatible class" do
    it "should raise an NotImplementedError if the class doesn't define method client" do
      lambda {
        Class.new { include AMQ::Client::Logging }
      }.should raise_error(NotImplementedError)
    end
  end

  context "including to a compatible class" do
    subject { LoggingTestClass.new }

    it "should be able to log via #client#logger of given class" do
      subject.logging = true
      subject.debug("message").should eql("message")
    end

    it "should not log anything if subject#logging is false" do
      subject.logging = false
      subject.debug("message").should be_nil
    end
  end
end
