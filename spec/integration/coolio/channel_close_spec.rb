# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Channel.Close", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 1

  it "should close the channel" do
    @events = []
    coolio_amqp_connect do |client|
      @events << :connect
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        @events << :open
        channel.close do
          @events << :close
          client.disconnect do
            @events << :disconnect
            done
          end
        end
      end
    end
    @events.should == [:connect, :open, :close, :disconnect]
  end
end