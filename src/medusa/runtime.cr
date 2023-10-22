module Medusa
  class Runtime
    alias QuickJS = Binding::QuickJS

    def initialize
      @rt = QuickJS.JS_NewRuntime
    end

    def to_unsafe
      @rt
    end
  end
end
