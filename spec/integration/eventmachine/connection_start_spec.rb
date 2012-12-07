# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

#
# We assume that default connection settings (amqp://guest:guest@localhost:5672/) should work
#
describe AMQ::Client::EventMachineClient, "Connection.Start" do
  include EventedSpec::SpecHelper
  default_timeout 0.5

  it "uses PLAIN authentication by default" do
    em do
      AMQ::Client::EventMachineClient.new(0).mechanism.should eq "PLAIN"
      done
    end
  end

  it "uses PLAIN authentication when explicitly set" do
    em do
      AMQ::Client::EventMachineClient.new(0, :auth_mechanism => "PLAIN").mechanism.should eq "PLAIN"
      done
    end
  end

  it "properly encodes username and password for PLAIN authentication" do
    em do
      client = AMQ::Client::EventMachineClient.new 0, :auth_mechanism => "PLAIN"
      client.encode_credentials("user", "pass").should eq "\0user\0pass"
      done
    end
  end

  it "uses EXTERNAL authentication when explicitly set" do
    em do
      AMQ::Client::EventMachineClient.new(0, :auth_mechanism => "EXTERNAL").mechanism.should eq "EXTERNAL"
      done
    end
  end

  it "skips encoding username and password for EXTERNAL authentication" do
    em do
      client = AMQ::Client::EventMachineClient.new 0, :auth_mechanism => "EXTERNAL"
      client.encode_credentials("user", "pass").should eq ""
      done
    end
  end

  it "allows user-defined authentication mechanisms" do
    Class.new AMQ::Client::Async::AuthMechanismAdapter do
      auth_mechanism "FOO"

      def encode_credentials(username, password)
        "foo"
      end
    end

    em do
      client = AMQ::Client::EventMachineClient.new 0, :auth_mechanism => "FOO"
      client.encode_credentials("user", "pass").should eq "foo"
      done
    end
  end

  it "fails for unimplemented authentication mechanisms" do
    em do
      client = AMQ::Client::EventMachineClient.new 0, :auth_mechanism => "BAR"
      expect do
        client.encode_credentials("user", "pass")
      end.to raise_error(NotImplementedError)
      done
    end
  end

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
