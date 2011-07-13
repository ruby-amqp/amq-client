# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Connection.Close", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 0.5

  it "should issue a callback and close connection" do
    coolio do
      AMQ::Client::CoolioClient.connect do |connection|
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
