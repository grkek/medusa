module Medusa
  module Exceptions
    class RuntimeException < Exception
      alias QuickJS = Medusa::Binding::QuickJS

      def initialize(input : String?, eval_flag : QuickJS::Flag?, etag : String?, same_thread : Bool?)
        @message = String.build do |string|
          string << "A runtime exception occured:\n"
          string << "\t    E-Tag: #{etag}, Eval Flag: #{eval_flag}, Same Thread: #{same_thread}\n\n"
          string << "\t    Input: #{input[..32]}"
        end
      end
    end
  end
end
