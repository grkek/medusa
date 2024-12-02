module Medusa
  module Exceptions
    class TypeException < Exception
      def initialize(value)
        @message = String.build do |string|
          string << "A type exception occured, #{value}"
        end
      end
    end
  end
end
