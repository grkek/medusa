module Medusa
  class Runtime
    alias QuickJS = Binding::QuickJS

    def initialize
      @runtime = QuickJS.JS_NewRuntime
    end

    def to_unsafe
      @runtime
    end

    def finalize
      QuickJS.JS_FreeRuntime(@runtime)
    end
  end
end
