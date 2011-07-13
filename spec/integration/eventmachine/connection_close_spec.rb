# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Connection.Close" do
  include EventedSpec::SpecHelper
  default_timeout 0.5

  it "should issue a callback and close connection" do
    em do
      AMQ::Client::EventMachineClient.connect do |connection|
        @connection = connection
        connection.should be_opened
        connection.disconnect do
          done
        end
      end
    end
    @connection.should be_closed
  end
end
