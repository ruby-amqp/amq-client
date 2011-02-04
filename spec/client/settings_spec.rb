# encoding: utf-8

require "spec_helper"
require "amq/client/settings"

describe AMQ::Client::Settings do
  describe ".default" do
    it "should provide some default values" do
      AMQ::Client::Settings.default.should_not be_nil
      AMQ::Client::Settings.default[:host].should_not be_nil
    end
  end

  describe ".configure(&block)" do
    it "should merge custom settings with default settings" do
      settings = AMQ::Client::Settings.configure(:host => "tagadab")
      settings[:host].should eql("tagadab")
    end

    it "should merge custom settings from AMQP URL with default settings" do
      pending "AMQP URL parsing" do
        settings = AMQ::Client::Settings.configure("amqp://tagadab")
        settings[:host].should eql("tagadab")
      end
    end
  end
end
