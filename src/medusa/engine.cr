module Medusa
  class Engine
    alias QuickJS = Medusa::Binding::QuickJS

    property runtime : Medusa::Runtime = Medusa::Runtime.new
    property context : Medusa::Context

    def initialize
      @context = Medusa::Context.new(@runtime.to_unsafe)
    end

    def eval_string(input : String, eval_flag : QuickJS::Flag = QuickJS::Flag::STRICT, etag : String = "<input>", same_thread : Bool = true) : Medusa::ValueWrapper
      channel = Channel(ValueWrapper | Exception).new

      return context.eval_string(input, eval_flag, etag) if same_thread

      spawn do
        QuickJS.JS_UpdateStackTop(runtime.to_unsafe)

        begin
          channel.send(context.eval_string(input))
        rescue exception
          channel.send(exception)
        end
      end

      if value = channel.receive?
        return value.as(ValueWrapper) if value.is_a?(ValueWrapper)
        raise value.as(Exception) if value.is_a?(Exception)
      end

      raise Exceptions::RuntimeException.new(input: input, eval_flag: eval_flag, etag: etag, same_thread: same_thread)
    end
  end
end
