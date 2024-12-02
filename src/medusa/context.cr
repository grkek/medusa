module Medusa
  class Context
    alias QuickJS = Binding::QuickJS

    include API::Eval
    include API::Function

    def initialize(runtime : QuickJS::JSRuntime)
      @context = QuickJS.NewBuiltInContext(runtime)
    end

    def to_unsafe
      @context
    end

    def finalize
      QuickJS.JS_FreeContext(@context)
    end
  end
end
