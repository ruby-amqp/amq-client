# encoding: utf-8

require "ostruct"
require "spec_helper"
require "amq/client"

describe AMQ::Client do
  if RUBY_PLATFORM =~ /java/
    ADAPTERS = {
      :event_machine => "EventMachineClient",
      :socket        => "SocketClient"
    }
  else
    ADAPTERS = {
      :event_machine => "EventMachineClient",
      :coolio        => "CoolioClient",
      :socket        => "SocketClient"
    }
  end

  it "should have VERSION" do
    AMQ::Client::const_defined?(:VERSION).should be_true
  end

  ADAPTERS.each do |adapter_name, adapter_const_name|
    describe ".adapters" do
      before(:all) do
        @meta = AMQ::Client.adapters[adapter_name]
      end

      it "should provide info about path to the adapter" do
        lambda { require @meta[:path] }.should_not raise_error
      end

      it "should provide info about const_name" do
        @meta[:const_name].should eql(adapter_const_name)
      end
    end
  end

  describe ".connect(settings = nil, &block)" do
    include EventedSpec::SpecHelper
    default_timeout 1

    context "with specified adapter" do
      it "should connect using socket adapter" do
        pending "Socket adapter is currently broken" do
          AMQ::Client.connect(:adapter => :socket) do |client|
            client.class.name.should eql("AMQ::Client::SocketClient")
            done
          end
        end
      end

      it "should connect using event_machine adapter" do
        em do
          AMQ::Client.connect(:adapter => :event_machine) do |client|
            client.class.name.should eql("AMQ::Client::EventMachineClient")
            done
          end
        end
      end

      it "should connect using coolio adapter", :nojruby => true do
        coolio do
          AMQ::Client.connect(:adapter => :coolio) do |client|
            client.class.name.should eql("AMQ::Client::CoolioClient")
            done
          end
        end
      end
    end

    context "without any specified adapter" do
      it "should default to the socket adapter" do
        pending "Socket adapter is currently broken" do
          AMQ::Client.connect do |client|
            client.class.name.should eql("AMQ::Client::SocketClient")
            done
          end
        end
      end
    end
  end
end
