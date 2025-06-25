module Medusa
  module Exceptions
    class InternalException < Exception
      getter stack : String? = nil

      def initialize(message : String, stack : String?)
        @stack = stack
        @message = message
      end
    end
  end
end
