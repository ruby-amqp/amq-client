# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "handling immediate disconnection" do
  include EventedSpec::SpecHelper
  default_timeout 4

  after :all do
    done
  end

  it "successfully disconnects" do
    em_amqp_connect do
      EventMachine.run do
        c = described_class.connect

        c.disconnect do
          puts "Disconnection callback has fired!"
          done
        end
      end
    end # em_amqp_connect
  end # it
end # describe