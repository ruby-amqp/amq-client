# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Channel#flow" do
  include EventedSpec::SpecHelper
  default_timeout 2

  it "controls channel flow state" do
    em_amqp_connect do |client|
      flow_states = []

      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        channel.flow_is_active?.should be_true

        channel.flow(false) do |flow_status1|
          channel.flow_is_active?.should be_false
          flow_states << channel.flow_is_active?

          channel.flow(true) do |flow_status2|
            channel.flow_is_active?.should be_true
            flow_states << channel.flow_is_active?
          end # channel.flow
        end # channel.flow
      end # channel.open

      done(1.0) { flow_states.should == [false, true] }
    end # em_amqp_connect
  end # it
end # describe