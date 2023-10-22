require "./get"

module Medusa
  module API
    module Eval
      alias QuickJS = Binding::QuickJS

      include Get

      def eval_string(input : String, eval_flag : QuickJS::Flag = QuickJS::Flag::STRICT) : Value
        value = QuickJS.JS_Eval \
          @ctx, input, input.size, UUID.random.to_s + ".js", eval_flag

        if value.tag == QuickJS::Tag::EXCEPTION
          exception = get_exception

          case exception.to_unsafe.tag
          when QuickJS::Tag::STRING
            raise exception.to_s
          when QuickJS::Tag::OBJECT
            message = get_property_str(exception, "message")
            raise message.to_s
          end
        end

        Value.new(@ctx, value)
      end
    end
  end
end
