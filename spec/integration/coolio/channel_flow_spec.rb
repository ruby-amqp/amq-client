# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Channel.Flow", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 1

  it "should control the flow of channel" do
    coolio_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        channel.flow_is_active?.should be_true
        channel.flow(false) do |_, flow_active|
          flow_active.should be_false
          channel.flow(true) do |_, flow_active|
            flow_active.should be_true
          end
        end
        done
      end
    end
  end


  it "should not raise errors when no state change occurs" do
    coolio_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      expect {
        channel.open do
          channel.flow_is_active?.should be_true
          channel.flow(false) do |_, flow_active|
            flow_active.should be_false
            channel.flow(false) do |_, flow_active|
              flow_active.should be_false
            end
          end
          done
        end
      }.to_not raise_error
    end
  end
end