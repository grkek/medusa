module Medusa
  class Value
    alias QuickJS = Binding::QuickJS

    @ctx : QuickJS::JSContext
    @v : QuickJS::JSValue

    def initialize(@ctx : QuickJS::JSContext, @v : QuickJS::JSValue)
    end

    def to_s
      String.new(QuickJS.JS_ValueToCString(@ctx, @v))
    end

    def to_unsafe
      @v
    end
  end
end
