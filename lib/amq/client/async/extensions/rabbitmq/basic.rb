# encoding: utf-8

require "amq/client/async/channel"

# Basic.Nack
module AMQ
  module Client
    module Async
      module Extensions
        module RabbitMQ
          module Basic
            module ChannelMixin

              # Overrides {AMQ::Client::Channel#reject} behavior to use basic.nack.
              #
              # @api public
              # @see http://www.rabbitmq.com/amqp-0-9-1-quickref.html#basic.nack
              def reject(delivery_tag, requeue = true, multi = false)
                if multi
                  @connection.send_frame(Protocol::Basic::Nack.encode(self.id, delivery_tag, multi, requeue))
                else
                  super(delivery_tag, requeue)
                end
              end # reject

            end # ChannelMixin
          end # Basic
        end # RabbitMQ
      end # Extensions

      class Channel
        # use modules, the native Ruby way of extension of existing classes,
        # instead of reckless monkey-patching. MK.
        include Extensions::RabbitMQ::Basic::ChannelMixin
      end # Channel
    end # Async
  end # Client
end # AMQ
