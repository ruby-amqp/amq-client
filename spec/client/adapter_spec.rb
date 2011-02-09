# encoding: utf-8

require "ostruct"
require "spec_helper"
require "amq/client/adapter"

describe AMQ::Client::Adapter do
  before(:all) do
    load "amq/client.rb"
  end

  describe ".settings" do
    it "should provide some default values" do
      AMQ::Client::Adapter.settings.should_not be_nil
      AMQ::Client::Adapter.settings[:host].should_not be_nil
    end
  end

  describe "logging accessors" do
    it "should be the same as AMQ::Client::Logging.logging" do
      AMQ::Client::Adapter::logging.should == AMQ::Client::Logging.logging

      AMQ::Client::Adapter::logging = ! AMQ::Client::Adapter::logging
      AMQ::Client::Adapter::logging.should == AMQ::Client::Logging.logging

      AMQ::Client::Logging.logging = ! AMQ::Client::Logging.logging
      AMQ::Client::Adapter::logging.should == AMQ::Client::Logging.logging
    end
  end

  describe ".logger" do
    it "should provide a default logger if logging is on" do
      AMQ::Client::Adapter.logging = true

      AMQ::Client::Adapter.logger.should respond_to(:debug)
      AMQ::Client::Adapter.logger.should respond_to(:info)
      AMQ::Client::Adapter.logger.should respond_to(:error)
      AMQ::Client::Adapter.logger.should respond_to(:fatal)
    end

    it "should be nil if the logging is off" do
      AMQ::Client::Adapter.logging = false
      AMQ::Client::Adapter.logger.should be_nil
    end
  end

  describe ".logger=(logger)" do
    it "should raise an exception if the logger doesn't respond to all the necessary methods" do
      lambda {
        AMQ::Client::Adapter.logger = Object.new
      }.should raise_error(AMQ::Client::Logging::IncompatibleLoggerError)
    end

    it "should pass if the object provides all the necessary methods" do
      AMQ::Client::Adapter.logging = true

      mock = OpenStruct.new(:debug => nil, :info => nil, :error => nil, :fatal => nil)
      AMQ::Client::Adapter.logger = mock
      AMQ::Client::Adapter.logger.should eql(mock)
    end
  end
end
