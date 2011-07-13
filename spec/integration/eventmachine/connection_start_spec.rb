# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

#
# We assume that default connection settings (amqp://guest:guest@localhost:5672/) should work
#
describe AMQ::Client::EventMachineClient, "Connection.Start" do
  include EventedSpec::SpecHelper
  default_timeout 0.5

  context "with valid credentials" do
    it "should trigger the callback" do
      em do
        AMQ::Client::EventMachineClient.connect do |client|
          done
        end
      end
    end
  end

  context "with invalid credentials" do
    context "when given an errback" do
      it "should trigger the errback" do
        em do
          AMQ::Client::EventMachineClient.connect(:port => 12938, :on_tcp_connection_failure => proc { done }) do |client|
            raise "This callback should never happen"
          end
        end
      end
    end

    context "when given no errback" do
      it "should raise an error" do
        expect {
          em do
            AMQ::Client::EventMachineClient.connect(:port => 12938) { }
            done(0.5)
          end
        }.to raise_error(AMQ::Client::TCPConnectionFailed)
      end
    end
  end

end
