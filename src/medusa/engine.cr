module Medusa
  # Manages a QuickJS runtime and context for executing JavaScript code.
  # Provides methods to evaluate JavaScript strings and call JavaScript functions,
  # with support for same-thread execution and safer multithreaded handling.
  class Engine
    Log = ::Log.for(self)

    alias QuickJS = Binding::QuickJS

    getter runtime : Runtime
    getter context : Context

    # Initializes the engine with a new runtime and context.
    def initialize
      @runtime = Runtime.new
      @context = Context.new(@runtime.to_unsafe)
    end

    # Creates a ValueWrapper for a given value, encapsulating context access.
    def create_value(value) : ValueWrapper
      ValueWrapper.new(@context.to_unsafe, value)
    end

    # Evaluates a JavaScript string and returns the result as a ValueWrapper.
    def eval_string(input : String, eval_flag : QuickJS::Flag = QuickJS::Flag::STRICT, etag : String = "<input>", same_thread : Bool = true) : ValueWrapper
      execute(same_thread: same_thread) do
        result = context.eval_string(input, eval_flag, etag)
        handle_js_result(result, input: input, eval_flag: eval_flag, etag: etag, same_thread: same_thread)
      end
    end

    # Calls a JavaScript function with the given arguments and `this` context.
    def call(function : ValueWrapper, this : ValueWrapper, arguments : Array(ValueWrapper) = [] of ValueWrapper, same_thread : Bool = true) : ValueWrapper
      argument_count = arguments.size
      argument_vector = argument_count > 0 ? Pointer(QuickJS::JSValue).malloc(argument_count) : Pointer(QuickJS::JSValue).null

      # Duplicate JSValues to ensure they remain valid during execution
      arguments.each_with_index do |wrapper, idx|
        argument_vector[idx] = QuickJS.DupValue(context.to_unsafe, wrapper.to_unsafe)
      end

      execute(same_thread: same_thread, cleanup: -> {
        # Free duplicated JSValues and the argument vector
        argument_count.times { |i| QuickJS.FreeValue(context.to_unsafe, argument_vector[i]) }

        QuickJS.FreeValue(context.to_unsafe, argument_vector.value) unless argument_vector.null?
        argument_vector = Pointer(QuickJS::JSValue).null unless argument_vector.null?
      }) do
        result_value = QuickJS.JS_Call(context.to_unsafe, function.to_unsafe, this.to_unsafe, argument_count, argument_vector)
        # JS_Call returns a new JSValue that we own, so wrap it directly
        wrapper = ValueWrapper.new(context.to_unsafe, result_value)
        handle_js_result(wrapper, input: "<call>", eval_flag: nil, etag: nil, same_thread: same_thread)
      end
    end

    # Executes a block in the current thread or a new fiber, handling results and cleanup.
    private def execute(same_thread : Bool, cleanup : Proc(Nil)? = nil, &block : -> ValueWrapper) : ValueWrapper
      if same_thread
        begin
          result = block.call
          cleanup.call if cleanup
          return result
        rescue ex
          cleanup.call if cleanup
          raise ex
        end
      end

      channel = Channel(ValueWrapper | Exception).new

      spawn do
        QuickJS.JS_UpdateStackTop(runtime.to_unsafe)

        begin
          channel.send(block.call)
        rescue crystal_exception
          channel.send(crystal_exception)
        ensure
          cleanup.call if cleanup
        end
      end

      handle_channel_result(channel)
    end

    # Checks a result for JavaScript exceptions and raises if necessary.
    private def handle_js_result(result : ValueWrapper, input : String, eval_flag : QuickJS::Flag?, etag : String?, same_thread : Bool) : ValueWrapper
      if QuickJS.IsException(result.to_unsafe)
        exception_value = QuickJS.JS_GetException(context.to_unsafe)
        js_exception = ValueWrapper.new(context.to_unsafe, exception_value)

        message = js_exception["message"]?.try(&.as_s) || "Unknown JavaScript error"
        stack = js_exception["stack"]?.try(&.as_s)

        Log.error { "JS Exception: #{message}\nStack: #{stack}" } if stack

        # The exception ValueWrapper will handle freeing the JSValue in its finalizer
        raise Exceptions::InternalException.new(message: message, stack: stack.strip)
      end

      result
    end

    # Processes channel results, raising exceptions or returning values with a timeout.
    private def handle_channel_result(channel : Channel(ValueWrapper | Exception)) : ValueWrapper
      select
      when value = channel.receive
        case value
        when ValueWrapper then return value
        when Exception    then raise value
        end
      when timeout(5.seconds) # Timeout to prevent hanging on fiber crash
        raise Exceptions::RuntimeException.new(
          message: "Fiber failed to respond",
          input: "<unknown>",
          eval_flag: nil,
          etag: nil,
          same_thread: false
        )
      end

      ValueWrapper.new(context.to_unsafe, false)
    end

    # Finalizes the engine, freeing the context and runtime.
    def finalize
      @context.finalize
      @runtime.finalize
    end
  end
end
