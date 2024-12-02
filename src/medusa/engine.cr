module Medusa
  class Engine
    alias QuickJS = Binding::QuickJS

    property runtime : Runtime = Runtime.new
    property context : Context

    def initialize
      @context = Context.new(@runtime.to_unsafe)
    end

    def eval_string(input : String, eval_flag : QuickJS::Flag = QuickJS::Flag::STRICT, etag : String = "<input>", same_thread : Bool = true) : ValueWrapper
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

    def call(function : ValueWrapper, this : ValueWrapper, args : Array(ValueWrapper) = [] of ValueWrapper, same_thread : Bool = true) : ValueWrapper
      channel = Channel(ValueWrapper | Exception).new

      argc = args.size
      argv = Pointer(QuickJS::JSValue).malloc(args.size)

      # Populate the array with the JSValue pointers
      args.each_with_index do |wrapper, idx|
        argv[idx] = wrapper.to_unsafe
      end

      return ValueWrapper.new(context.to_unsafe, QuickJS.JS_Call(context.to_unsafe, function.to_unsafe, this.to_unsafe, argc, argv)) if same_thread

      spawn do
        QuickJS.JS_UpdateStackTop(runtime.to_unsafe)

        begin
          channel.send(ValueWrapper.new(context.to_unsafe, QuickJS.JS_Call(context.to_unsafe, function.to_unsafe, this.to_unsafe, argc, argv)))
        rescue exception
          channel.send(exception)
        end
      end

      if value = channel.receive?
        return value.as(ValueWrapper) if value.is_a?(ValueWrapper)
        raise value.as(Exception) if value.is_a?(Exception)
      end

      raise Exceptions::RuntimeException.new(input: "<call>", eval_flag: nil, etag: nil, same_thread: same_thread)
    end
  end
end
