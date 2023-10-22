module Medusa
  class Context
    alias QuickJS = Binding::QuickJS

    include API::Eval
    include API::Function
    include API::Get
    include API::Set

    def initialize(rt : QuickJS::JSRuntime)
      @ctx = QuickJS.JS_NewContext(rt)
    end

    def to_unsafe
      @ctx
    end
  end
end
