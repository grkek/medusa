module Medusa
  module API
    module Eval
      alias QuickJS = Binding::QuickJS

      def eval_string(input : String, eval_flag : QuickJS::Flag = QuickJS::Flag::STRICT, etag : String = "<input>") : ValueWrapper
        value = QuickJS.JS_Eval(@context, input, input.size, etag, eval_flag)

        if value.tag == QuickJS::Tag::EXCEPTION
          exception = ValueWrapper.new(@context, QuickJS.JS_GetException(@context))

          case exception.to_unsafe.tag
          when QuickJS::Tag::STRING
            raise Exceptions::InternalException.new(message: exception.as_s, stack: nil)
          when QuickJS::Tag::OBJECT
            if QuickJS.JS_IsError(@context, exception)
              stack_value = exception["stack"]

              unless QuickJS.IsUndefined(stack_value)
                raise Exceptions::InternalException.new(message: exception.["message"].as_s, stack: stack_value.as_s)
              end
            end

            raise Exceptions::InternalException.new(message: exception.["message"].as_s, stack: nil)
          end
        end

        ValueWrapper.new(@context, value)
      end
    end
  end
end
