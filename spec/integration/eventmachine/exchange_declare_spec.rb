# encoding: utf-8

require 'spec_helper'
require 'integration/eventmachine/spec_helper'

describe AMQ::Client::EventMachineClient, "Exchange.Declare" do

  #
  # Environment
  #

  include EventedSpec::SpecHelper
  default_timeout 2
  let(:exchange_name) { "amq-client.testexchange.#{Time.now.to_i}" }



  #
  # Examples
  #

  context "when exchange type is non-standard" do
    context "and DOES NOT begin with x-" do
      it "raises an exception" do
        em_amqp_connect do |client|
          channel = AMQ::Client::Channel.new(client, 1)
          channel.open do
            begin
              AMQ::Client::Exchange.new(client, channel, exchange_name, "my_shiny_metal_exchange_type")
            rescue AMQ::Client::UnknownExchangeTypeError => e
              done
            end
          end # channel.open
        end # em_amqp_connect
      end # it
    end # context
  end # context



  it "should create an exchange and trigger a callback" do
    em_amqp_connect do |client|
      channel = AMQ::Client::Channel.new(client, 1)
      channel.open do
        exchange = AMQ::Client::Exchange.new(client, channel, exchange_name, "fanout")
        exchange.declare do
          exchange.delete
          done(0.2)
        end
      end
    end
  end # it "should create an exchange and trigger a callback"

  context "options" do
    context "passive" do
      context "when set" do
        it "should trigger channel level error if given exchange doesn't exist" do
          em_amqp_connect do |client|
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
              done(0.3)
            end
          end

          @callback_fired.should be_false
          @error_fired.should be_true
        end # it "should trigger channel level error if given exchange doesn't exist"

        it "should raise no error and fire the callback if given exchange exists" do
          em_amqp_connect do |client|
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
              done(0.3)
            end
          end

          @callback_fired.should be_true
          @error_fired.should be_false
        end # it "should raise no error and fire the callback if given exchange exists"
      end # context "when set"

      context "when unset" do
        it "should raise no error and fire the callback if given exchange doesn't exist" do
          em_amqp_connect do |client|
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
              done(0.3)
            end
          end

          @callback_fired.should be_true
          @error_fired.should be_false
        end # it "should raise no error and fire the callback if given exchange doesn't exist"

        it "should raise no error and fire the callback if given exchange exists" do
          em_amqp_connect do |client|
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
              done(0.3)
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
