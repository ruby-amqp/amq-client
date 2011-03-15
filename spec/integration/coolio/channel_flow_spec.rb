require 'spec_helper'
require 'integration/coolio/spec_helper'

describe AMQ::Client::Coolio, "Channel.Flow" do
  include EventedSpec::SpecHelper
  default_timeout 1

  it "should control the flow of channel" do
    coolio_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        AMQ::Client::Queue.new(client, channel).declare(false, false, false, true) do |q, _, _, _|
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
  end


  it "should not raise errors when no state change occurs" do
    coolio_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      expect {
        channel.open do
          AMQ::Client::Queue.new(client, channel).declare(false, false, false, true) do |q, _, _, _|
            channel.flow_is_active?.should be_true
            channel.flow(false) do |_, flow_active|
              flow_active.should be_false
              channel.flow(false) do |_, flow_active|
                flow_active.should be_false
              end
            end
            done
          end
        end
      }.to_not raise_error
    end
  end
end