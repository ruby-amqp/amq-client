# encoding: utf-8

require "amq/client/amqp/channel"

# Basic.Nack
module AMQ
  module Client
    module Extensions
      module RabbitMQ
        class Channel < ::AMQ::Client::Channel
          # http://www.rabbitmq.com/amqp-0-9-1-quickref.html#basic.nack
          def reject(delivery_tag, requeue = true, multi = false)
            if multi
              @client.send(Protocol::Basic::Nack.encode(self.id, delivery_tag, multi, requeue))
            else
              super(delivery_tag, requeue)
            end
          end
        end
      end
    end
  end
end
