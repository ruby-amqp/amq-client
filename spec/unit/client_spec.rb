# encoding: utf-8

require "ostruct"
require "spec_helper"
require "amq/client"

describe AMQ::Client do
  if RUBY_PLATFORM =~ /java/
    ADAPTERS = {
      :event_machine => "Async::EventMachineClient"
    }
  else
    ADAPTERS = {
      :event_machine => "Async::EventMachineClient",
      :coolio        => "Async::CoolioClient"
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
        require @meta[:path]
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
      it "should connect using event_machine adapter" do
        em do
          AMQ::Client.connect(:adapter => :event_machine) do |client|
            client.class.name.should eql("AMQ::Client::Async::EventMachineClient")
            done
          end
        end
      end # it

      it "should connect using coolio adapter", :nojruby => true do
        coolio do
          AMQ::Client.connect(:adapter => :coolio) do |client|
            client.class.name.should eql("AMQ::Client::Async::CoolioClient")
            done
          end
        end
      end # it
    end # context "with specified adapter"
  end # describe .connect
end # describe AMQ::Client
