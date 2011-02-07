# encoding: utf-8

require "ostruct"
require "spec_helper"

describe AMQ::Client do
  before(:all) do
    load "amq/client.rb"
  end

  subject { AMQ::Client }

  describe ".settings" do
    it "should provide some default values" do
      AMQ::Client.settings.should_not be_nil
      AMQ::Client.settings[:host].should_not be_nil
    end
  end

  describe "logging accessors" do
    it "should be the same as AMQ::Client::Logging.logging" do
      AMQ::Client::logging.should == AMQ::Client::Logging.logging

      AMQ::Client::logging = ! AMQ::Client::logging
      AMQ::Client::logging.should == AMQ::Client::Logging.logging

      AMQ::Client::Logging.logging = ! AMQ::Client::Logging.logging
      AMQ::Client::logging.should == AMQ::Client::Logging.logging
    end
  end

  describe ".logger" do
    it "should provide a default logger if logging is on" do
      AMQ::Client.logging = true

      AMQ::Client.logger.should respond_to(:debug)
      AMQ::Client.logger.should respond_to(:info)
      AMQ::Client.logger.should respond_to(:error)
      AMQ::Client.logger.should respond_to(:fatal)
    end

    it "should be nil if the logging is off" do
      AMQ::Client.logging = false
      AMQ::Client.logger.should be_nil
    end
  end

  describe ".logger=(logger)" do
    it "should raise an exception if the logger doesn't respond to all the necessary methods" do
      lambda {
        AMQ::Client.logger = Object.new
      }.should raise_error(AMQ::Client::Logging::IncompatibleLoggerError)
    end

    it "should pass if the object provides all the necessary methods" do
      AMQ::Client.logging = true

      mock = OpenStruct.new(:debug => nil, :info => nil, :error => nil, :fatal => nil)
      AMQ::Client.logger = mock
      AMQ::Client.logger.should eql(mock)
    end
  end
end
