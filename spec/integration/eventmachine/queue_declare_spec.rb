# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "queue.declare" do

  #
  # Environment
  #

  include EventedSpec::SpecHelper
  default_timeout 1



  #
  # Examples
  #

  context "when queue name is nil" do
    it "raises ArgumentError" do
      em_amqp_connect do |connection|
        ch = AMQ::Client::Channel.new(connection, 1)
        ch.open do |ch|
          begin
            AMQ::Client::Queue.new(connection, ch, nil)
          rescue ArgumentError => ae
            ae.message.should =~ /queue name must not be nil/

            done
          end
        end
      end
    end
  end # context
end
