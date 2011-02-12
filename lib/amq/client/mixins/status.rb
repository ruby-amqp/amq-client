# encoding: utf-8

module AMQ
  module Client
    module StatusMixin
      VALUES = [:opened, :closed, :opening, :closing].freeze

      class ImproperStatusError < StandardError
        def initialize(value)
          super("Value #{value.inspect} isn't permitted. Choose one of: #{AMQ::Client::StatusMixin::VALUES.inspect}")
        end
      end

      attr_reader :status
      def status=(value)
        if VALUES.include?(value)
          @status = value
        else
          raise ImproperStatusError.new(value)
        end
      end

      def opened?
        @status == :opened
      end

      def closed?
        @status == :closed
      end

      def opening?
        @status == :opening
      end

      def closing?
        @status == :closing
      end
    end
  end
end
