module Medusa
  module API
    module Set
      alias QuickJS = Binding::QuickJS

      def set_property_str(this_obj : QuickJS::JSValue, prop : String, val : QuickJS::JSValue) : LibC::Int
        QuickJS.JS_SetPropertyStr @ctx, this_obj, prop, val
      end
    end
  end
end
