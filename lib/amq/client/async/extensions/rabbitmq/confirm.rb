# encoding: utf-8

module AMQ
  module Client
    module Async
      module Extensions
        module RabbitMQ
          # h2. Purpose
          # In case that the broker crashes, some messages can get lost.
          # Thanks to this extension, broker sends Basic.Ack when the message
          # is processed by the broker. In case of persistent messages, it must
          # be written to disk or ack'd on all the queues it was delivered to.
          # However it doesn't have to be necessarily 1:1, because the broker
          # can send Basic.Ack with multi flag to acknowledge multiple messages.
          #
          # So it provides clients a lightweight way of keeping track of which
          # messages have been processed by the broker and which would need
          # re-publishing in case of broker shutdown or network failure.
          #
          # Transactions are solving the same problem, but they are very slow:
          # confirmations are more than 100 times faster.
          #
          # h2. Workflow
          # * Client asks broker to confirm messages on given channel (Confirm.Select).
          # * Broker sends back Confirm.Select-Ok, unless we sent Confirm.Select with nowait=true.
          # * After each published message, the client receives Basic.Ack from the broker.
          # * If something bad happens inside the broker, it sends Basic.Nack.
          #
          # h2. Gotchas
          # Note that we don't keep track of messages awaiting confirmation.
          # It'd add a huge overhead and it's impossible to come up with one-suits-all solution.
          # If you want to create such module, you'll probably want to redefine Channel#after_publish,
          # so it will put messages into a queue and then handlers for Basic.Ack and Basic.Nack.
          # This is the reason why we pass every argument from Exchange#publish to Channel#after_publish.
          # You should not forget though, that both of these methods can have multi flag!
          #
          # Transactional channel cannot be put into confirm mode and a confirm
          # mode channel cannot be made transactional.
          #
          # If the connection between the publisher and broker drops with outstanding
          # confirms, it does not necessarily mean that the messages were lost, so
          # republishing may result in duplicate messages.

          # h2. Learn more
          # @see http://www.rabbitmq.com/blog/2011/02/10/introducing-publisher-confirms
          # @see http://www.rabbitmq.com/amqp-0-9-1-quickref.html#class.confirm
          # @see http://www.rabbitmq.com/amqp-0-9-1-reference.html#basic.ack
          module Confirm
            module ChannelMixin

              # Change publisher index. Publisher index is incremented
              # by 1 after each Basic.Publish starting at 1. This is done
              # on both client and server, hence this acknowledged messages
              # can be matched via its delivery-tag.
              #
              # @api private
              attr_writer :publisher_index

              # Publisher index is an index of the last message since
              # the confirmations were activated, started with 0. It's
              # incremented by 1 every time a message is published.
              # This is done on both client and server, hence this
              # acknowledged messages can be matched via its delivery-tag.
              #
              # @return [Integer] Current publisher index.
              # @api public
              def publisher_index
                @publisher_index ||= 0
              end

              # Resets publisher index to 0
              #
              # @api plugin
              def reset_publisher_index!
                @publisher_index = 0
              end


              # This method is executed after publishing of each message via {Exchage#publish}.
              # Currently it just increments publisher index by 1, so messages
              # can be actually matched.
              #
              # @api plugin
              def increment_publisher_index!
                @publisher_index += 1
              end

              # Turn on confirmations for this channel and, if given,
              # register callback for Confirm.Select-Ok.
              #
              # @raise [RuntimeError] Occurs when confirmations are already activated.
              # @raise [RuntimeError] Occurs when nowait is true and block is given.
              #
              # @param [Boolean] nowait Whether we expect Confirm.Select-Ok to be returned by the broker or not.
              # @yield [method] Callback which will be executed once we receive Confirm.Select-Ok.
              # @yieldparam [AMQ::Protocol::Confirm::SelectOk] method Protocol method class instance.
              #
              # @return [self] self.
              #
              # @see #confirm
              def confirm_select(nowait = false, &block)
                if nowait && block
                  raise ArgumentError, "confirm.select with nowait = true and a callback makes no sense"
                end

                @uses_publisher_confirmations = true
                reset_publisher_index!

                self.redefine_callback(:confirm_select, &block) unless nowait
                self.redefine_callback(:after_publish) do
                  increment_publisher_index!
                end
                @connection.send_frame(Protocol::Confirm::Select.encode(@id, nowait))

                self
              end

              # @return [Boolean]
              def uses_publisher_confirmations?
                @uses_publisher_confirmations
              end # uses_publisher_confirmations?


              # Turn on confirmations for this channel and, if given,
              # register callback for basic.ack from the broker.
              #
              # @raise [RuntimeError] Occurs when confirmations are already activated.
              # @raise [RuntimeError] Occurs when nowait is true and block is given.
              # @param [Boolean] nowait Whether we expect Confirm.Select-Ok to be returned by the broker or not.
              #
              # @yield [basick_ack] Callback which will be executed every time we receive Basic.Ack from the broker.
              # @yieldparam [AMQ::Protocol::Basic::Ack] basick_ack Protocol method class instance.
              #
              # @return [self] self.
              def on_ack(nowait = false, &block)
                self.use_publisher_confirmations! unless self.uses_publisher_confirmations?

                self.define_callback(:ack, &block) if block

                self
              end


              # Register error callback for Basic.Nack. It's called
              # when message(s) is rejected.
              #
              # @return [self] self
              def on_nack(&block)
                self.define_callback(:nack, &block) if block

                self
              end




              # Handler for Confirm.Select-Ok. By default, it just
              # executes hook specified via the #confirmations method
              # with a single argument, a protocol method class
              # instance (an instance of AMQ::Protocol::Confirm::SelectOk)
              # and then it deletes the callback, since Confirm.Select
              # is supposed to be sent just once.
              #
              # @api plugin
              def handle_select_ok(method)
                self.exec_callback_once(:confirm_select, method)
              end

              # Handler for Basic.Ack. By default, it just
              # executes hook specified via the #confirm method
              # with a single argument, a protocol method class
              # instance (an instance of AMQ::Protocol::Basic::Ack).
              #
              # @api plugin
              def handle_basic_ack(method)
                self.exec_callback(:ack, method)
              end


              # Handler for Basic.Nack. By default, it just
              # executes hook specified via the #confirm_failed method
              # with a single argument, a protocol method class
              # instance (an instance of AMQ::Protocol::Basic::Nack).
              #
              # @api plugin
              def handle_basic_nack(method)
                self.exec_callback(:nack, method)
              end


              def reset_state!
                super

                @uses_publisher_confirmations = false
              end


              def self.included(host)
                host.handle(Protocol::Confirm::SelectOk) do |connection, frame|
                  method  = frame.decode_payload
                  channel = connection.channels[frame.channel]
                  channel.handle_select_ok(method)
                end

                host.handle(Protocol::Basic::Ack) do |connection, frame|
                  method  = frame.decode_payload
                  channel = connection.channels[frame.channel]
                  channel.handle_basic_ack(method)
                end

                host.handle(Protocol::Basic::Nack) do |connection, frame|
                  method  = frame.decode_payload
                  channel = connection.channels[frame.channel]
                  channel.handle_basic_nack(method)
                end
              end # self.included(host)
            end # ChannelMixin
          end # Confirm
        end # RabbitMQ
      end # Extensions


      class Channel
        # use modules, a native Ruby way of extension of existing classes,
        # instead of reckless monkey-patching. MK.
        include Extensions::RabbitMQ::Confirm::ChannelMixin
      end # Channel
    end # Async
  end # Client
end # AMQ
