module Medusa
  module Exceptions
    class InternalException < Exception
      def initialize(message : String, stack : String?)
        @message = String.build do |string|
          string << "An internal exception occured\n"
          string << "\t    Message: #{message}\n"
          string << "\t      Stack: #{stack}"
        end
      end
    end
  end
end
