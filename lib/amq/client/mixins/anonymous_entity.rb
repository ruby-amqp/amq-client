# encoding: utf-8

module AMQ
  module Client
    module AnonymousEntityMixin
      def anonymous?
        @name.nil? or @name.empty?
      end

      def dup
        if @name.eql?("")
          raise RuntimeError.new("You can't clone anonymous queue until it receives back the name in Queue.Declare-Ok response. Move the code with #dup to the callback for the #declare method.") # TODO: that's not true in all cases, imagine the user didn't call #declare yet.
        end
        instance = self.dup
        instance.instance_variable_set(:@consumer_tag, nil)
        instance
      end
    end
  end
end
