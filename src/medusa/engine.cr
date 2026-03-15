module Medusa
  # Manages a QuickJS runtime and context for executing JavaScript code.
  #
  # IMPORTANT: Always call `close` when done. Do not rely solely on GC
  # finalization — Boehm GC runs finalizers in non-deterministic order.
  class Engine
    Log = ::Log.for(self)

    alias QuickJS = Binding::QuickJS

    getter runtime : Runtime
    getter context : Context

    def initialize
      @closed = false
      @has_std_handlers = true
      @runtime = Runtime.new
      @runtime.setup_module_loader
      @context = Context.new(@runtime.to_unsafe)
    end

    def initialize(*, raw : Bool)
      @closed = false
      @has_std_handlers = !raw
      @runtime = Runtime.new
      @runtime.setup_module_loader
      @context = Context.new(@runtime.to_unsafe, raw: raw)
    end

    def create_value(value) : ValueWrapper
      ValueWrapper.new(@context.to_unsafe, value)
    end

    def eval_string(input : String, eval_flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, etag : String = "<input>", same_thread : Bool = true) : ValueWrapper
      execute(same_thread: same_thread) do
        context.eval_string(input, eval_flag, etag)
      end
    end

    def eval_this(this_obj : ValueWrapper, input : String, eval_flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, etag : String = "<input>", same_thread : Bool = true) : ValueWrapper
      execute(same_thread: same_thread) do
        context.eval_this(this_obj, input, eval_flag, etag)
      end
    end

    def call(function : ValueWrapper, this_obj : ValueWrapper, arguments : Array(ValueWrapper) = [] of ValueWrapper, same_thread : Bool = true) : ValueWrapper
      execute(same_thread: same_thread) do
        function.call(this_obj, arguments)
      end
    end

    def drain_jobs : Int32
      runtime.drain_jobs
    end

    private def execute(same_thread : Bool, &block : -> ValueWrapper) : ValueWrapper
      if same_thread
        return block.call
      end

      channel = Channel(ValueWrapper | Exception).new

      spawn do
        QuickJS.JS_UpdateStackTop(runtime.to_unsafe)
        begin
          channel.send(block.call)
        rescue crystal_exception
          channel.send(crystal_exception)
        end
      end

      handle_channel_result(channel)
    end

    private def handle_channel_result(channel : Channel(ValueWrapper | Exception)) : ValueWrapper
      select
      when value = channel.receive
        case value
        when ValueWrapper then return value
        when Exception    then raise value
        end
      when timeout(5.seconds)
        raise Exceptions::RuntimeException.new(
          message: "Fiber failed to respond within timeout",
          input: "<unknown>",
          eval_flag: nil,
          etag: nil,
          same_thread: false
        )
      end

      ValueWrapper.new(context.to_unsafe, false)
    end

    # --- Cleanup ---

    # Shuts down the engine. The C++ FreeContextAndRuntime handles the
    # QuickJS gc_obj_list assertion issue caused by Crystal ValueWrappers
    # that haven't been GC'd yet.
    def close : Nil
      return if @closed
      @closed = true

      begin
        @runtime.drain_jobs
      rescue
      end

      QuickJS.FreeContextAndRuntime(@context.to_unsafe, @runtime.to_unsafe, @has_std_handlers ? 1 : 0)

      # Mark as freed so Boehm GC finalizers on Context/Runtime are no-ops
      @context.mark_freed!
      @runtime.mark_freed!
    end

    def closed? : Bool
      @closed
    end

    def finalize
      close
    end
  end
end
