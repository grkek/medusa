module Medusa
  module API
    module Function
      alias QuickJS = Binding::QuickJS

      def new_c_function_pointer(procedure : Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)) : QuickJS::JSCFunction
        QuickJS.NewCFunctionPointer Glue.wrap_procedure(procedure)
      end

      def new_c_function(function_pointer : QuickJS::JSCFunction, name : String, length : LibC::Int) : Value
        Value.new(@context, QuickJS.NewCFunction(@context, function_pointer, name, length))
      end
    end
  end
end
