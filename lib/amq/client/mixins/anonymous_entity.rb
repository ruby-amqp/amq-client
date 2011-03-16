# encoding: utf-8

module AMQ
  module Client
    # Common behavior of AMQ entities that can be either client or server-named, for example, exchanges and queues.
    module AnonymousEntityMixin

      # @return [Boolean] true if this entity is anonymous (server-named)
      def anonymous?
        @name.nil? or @name.empty?
      end

      def dup
        if @name.empty?
          raise RuntimeError.new("You can't clone anonymous queue until it receives back the name in Queue.Declare-Ok response. Move the code with #dup to the callback for the #declare method.") # TODO: that's not true in all cases, imagine the user didn't call #declare yet.
        end
        super
      end
    end # AnonymousEntityMixin
  end # Client
end # AMQ
