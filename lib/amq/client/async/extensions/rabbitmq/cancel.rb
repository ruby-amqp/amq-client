# encoding: utf-8

require "amq/client/async/channel"

# Basic.Cancel
module AMQ
  module Client
    module Async
      module Extensions
        module RabbitMQ
          module Basic
            module ConsumerMixin

              def on_cancel(&block)
                self.append_callback(:scancel, &block)

                self
              end # on_cancel(&block)

              def handle_cancel(basic_cancel)
                self.exec_callback(:scancel, basic_cancel)
              end # handle_cancel(basic_cancel)

              def self.included receiver
                receiver.handle(Protocol::Basic::Cancel) do |connection, method_frame|
                  channel      = connection.channels[method_frame.channel]
                  basic_cancel = method_frame.decode_payload
                  consumer     = channel.consumers[basic_cancel.consumer_tag]

                  # Handle the delivery only if the consumer still exists.
                  consumer.handle_cancel(basic_cancel) if consumer
                end
              end

            end # ConsumerMixin

            module QueueMixin

              # @api public
              def on_cancel(&block)
                @default_consumer.on_cancel(&block)
              end # on_cancel(&block)
            end

          end # Basic
        end # RabbitMQ
      end # Extensions

      class Consumer
        include Extensions::RabbitMQ::Basic::ConsumerMixin
      end # Consumer

      class Queue
        include Extensions::RabbitMQ::Basic::QueueMixin
      end # Queue

    end # Async
  end # Client
end # AMQ
