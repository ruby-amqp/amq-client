# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Channel.Close" do
  include EventedSpec::SpecHelper
  default_timeout 1

  it "should close the channel" do
    @events = []
    em_amqp_connect do |connection|
      @events << :connect
      channel = AMQ::Client::Channel.new(connection, 1)
      channel.open do
        @events << :open
        channel.close do
          @events << :close
          connection.disconnect do
            @events << :disconnect
            done
          end
        end
      end
    end
    @events.should == [:connect, :open, :close, :disconnect]
  end
end
