# encoding: utf-8

require "amq/client/entity"

module AMQ
  module Client
    class Channel < Entity
      def initialize(adapter, id)
        super(adapter)
        @id = id
      end

      def open(&block)
      end

      def close(&block)
      end
    end
  end
end
