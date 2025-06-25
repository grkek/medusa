module Medusa
  module API
    module Eval
      alias QuickJS = Binding::QuickJS

      def eval_string(input : String, eval_flag : QuickJS::Flag = QuickJS::Flag::STRICT, etag : String = "<input>") : ValueWrapper
        # JS_Eval returns a new JSValue that we own
        value = QuickJS.JS_Eval(@context, input, input.bytesize, etag, eval_flag.value)

        # Check for exception before wrapping
        if value.tag == QuickJS::Tag::EXCEPTION
          # Get the exception details
          exception_value = QuickJS.JS_GetException(@context)
          exception = ValueWrapper.new(@context, exception_value)

          message = exception["message"]?.try(&.as_s) || "Unknown error"
          stack = exception["stack"]?.try(&.as_s)

          # Free the original exception JSValue and let ValueWrapper handle the exception_value
          QuickJS.FreeValue(@context, value)

          raise Exceptions::InternalException.new(message: message, stack: stack)
        end

        # Wrap the JSValue - ValueWrapper will handle the reference counting
        ValueWrapper.new(@context, value)
      end
    end
  end
end
