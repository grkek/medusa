module Medusa
  module API
    module Get
      alias QuickJS = Binding::QuickJS

      def get_global_object : Value
        Value.new(@ctx, QuickJS.JS_GetGlobalObject(@ctx))
      end

      def get_property_str(object : Value, prop : String)
        Value.new(@ctx, QuickJS.JS_GetPropertyStr(@ctx, object.to_unsafe, prop))
      end

      def get_exception : Value
        Value.new(@ctx, QuickJS.JS_GetException(@ctx))
      end
    end
  end
end
