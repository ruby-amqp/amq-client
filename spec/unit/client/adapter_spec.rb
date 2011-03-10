# encoding: utf-8

require "ostruct"
require "spec_helper"
require "amq/client/adapter"

class SampleAdapter
  include AMQ::Client::Adapter
end

describe SampleAdapter do
  before(:all) do
    load "amq/client.rb"
  end

  describe ".settings" do
    it "should provide some default values" do
      described_class.settings.should_not be_nil
      described_class.settings[:host].should_not be_nil
    end
  end

  describe ".logger" do
    it "should provide a default logger" do
      described_class.logger.should respond_to(:debug)
      described_class.logger.should respond_to(:info)
      described_class.logger.should respond_to(:error)
      described_class.logger.should respond_to(:fatal)
    end
  end

  describe ".logger=(logger)" do
    context "when new logger doesn't respond to all the necessary methods" do
      it "should raise an exception" do
        lambda {
          described_class.logger = Object.new
        }.should raise_error(AMQ::Client::Logging::IncompatibleLoggerError)
      end

      it "should pass if the object provides all the necessary methods" do
        described_class.logging = true

        mock = OpenStruct.new(:debug => nil, :info => nil, :error => nil, :fatal => nil)
        described_class.logger = mock
        described_class.logger.should eql(mock)
      end
    end
  end
end
