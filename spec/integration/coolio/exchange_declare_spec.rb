# encoding: utf-8

require 'spec_helper'
require 'integration/coolio/spec_helper'

describe "AMQ::Client::CoolioClient", "Exchange.Declare", :nojruby => true do
  include EventedSpec::SpecHelper
  default_timeout 2
  let(:exchange_name) { "amq-client.testexchange.#{Time.now.to_i}" }
  it "should create an exchange and trigger a callback" do
    coolio_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
        exchange.declare do
          exchange.delete
          done(0.5)
        end
      end
    end
  end # it "should create an exchange and trigger a callback"

  context "options" do
    context "passive" do
      context "when set" do
        it "should trigger channel level error if given exchange doesn't exist" do
          coolio_amqp_connect do |client|
            channel = AMQ::Client::Channel.new(client, 1)
            channel.open do
              channel.on_error do
                @error_fired = true
              end
              exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
              exchange.declare(true, false, false, false) do
                @callback_fired = true
              end
              delayed(0.1) { exchange.delete }
              done(0.5)
            end
          end

          @callback_fired.should be_false
          @error_fired.should be_true
        end # it "should trigger channel level error if given exchange doesn't exist"

        it "should raise no error and fire the callback if given exchange exists" do
          coolio_amqp_connect do |client|
            channel = AMQ::Client::Channel.new(client, 1)
            channel.open do
              channel.on_error do
                @error_fired = true
              end
              exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
              exchange.declare(false, false, false, false) do # initial declaration
                AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout).declare(true) do
                  @callback_fired = true
                end
              end
              delayed(0.1) { exchange.delete }
              done(0.5)
            end
          end

          @callback_fired.should be_true
          @error_fired.should be_false
        end # it "should raise no error and fire the callback if given exchange exists"
      end # context "when set"

      context "when unset" do
        it "should raise no error and fire the callback if given exchange doesn't exist" do
          coolio_amqp_connect do |client|
            channel = AMQ::Client::Channel.new(client, 1)
            channel.open do
              channel.on_error do
                @error_fired = true
              end
              exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
              exchange.declare(false, false, false, false) do
                @callback_fired = true
              end
              delayed(0.1) { exchange.delete }
              done(0.5)
            end
          end

          @callback_fired.should be_true
          @error_fired.should be_false
        end # it "should raise no error and fire the callback if given exchange doesn't exist"

        it "should raise no error and fire the callback if given exchange exists" do
          coolio_amqp_connect do |client|
            channel = AMQ::Client::Channel.new(client, 1)
            channel.open do
              channel.on_error do
                @error_fired = true
              end
              exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout)
              exchange.declare(false, false, false, false) do # initial declaration
                AMQ::Client::Exchange.new(client, channel, exchange_name, :fanout).declare(false) do
                  @callback_fired = true
                end
              end
              delayed(0.1) { exchange.delete }
              done(0.5)
            end
          end

          @callback_fired.should be_true
          @error_fired.should be_false
        end # it "should raise no error and fire the callback if given exchange exists"
      end # context "when unset"
    end # context "passive"

    # Other options make little sense to test

  end # context "options"
end # describe
