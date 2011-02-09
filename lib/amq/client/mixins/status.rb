# encoding: utf-8

module AMQ
  module Client
    module StatusMixin
      VALUES ||= [:opened, :closed, :opening, :closing]

      class ImproperStatusError < StandardError
        def initialize(value)
          super("Value #{value.inspect} isn't permitted. Choose one of: #{Status::VALUES.inspect}")
        end
      end

      attr_reader :status
      def status=(status)
        if VALUES.include?(status)
          @status = status
        else
          raise ImproperStatusError.new(status)
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
