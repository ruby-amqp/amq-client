# encoding: utf-8

require "amq/client/entity"

module AMQ
  module Client
    class Exchange < Entity
    end
  end

  Adapter.register_entity(:exchange, Exchange)
end
