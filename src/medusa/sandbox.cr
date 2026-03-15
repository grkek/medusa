module Medusa
  # Thread-safe wrapper around `Medusa::Engine` for sandboxed JavaScript execution.
  #
  # Designed for long-lived contexts like GUI event loops where multiple fibers
  # may need to evaluate JS. All public methods acquire the mutex unless noted.
  #
  # The key GC design principle: Crystal closures that cross into QuickJS are
  # wrapped once via `bind`/`bind_raw` and stored as QuickJS function objects.
  # This avoids repeatedly passing Crystal Proc objects through the FFI boundary,
  # which is what caused GC issues with Duktape — the Crystal GC could collect
  # a Proc whose closure data was still referenced from the JS side.
  #
  # ```
  # sandbox = Medusa::Sandbox.new
  # sandbox.eval!("1 + 2")                        # => ValueWrapper (3)
  # sandbox.eval_mutex!("globalThis.x = 42")       # thread-safe eval
  # sandbox.bind("log", 1) { |args| puts args[0].as_s; nil }
  # ```
  class Sandbox
    Log = ::Log.for(self)

    alias QuickJS = Binding::QuickJS

    getter engine : Engine

    @mutex : Mutex
    # Prevents Boehm GC from collecting closures that have been passed to
    # QuickJS via bind/bind_raw. Without this, the GC sees no Crystal-side
    # reference to the Proc's closure data and collects it, causing SIGBUS/
    # SIGSEGV when QuickJS later invokes the callback.
    @prevent_gc : Array(Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue))

    def initialize
      @engine = Engine.new
      @mutex = Mutex.new(:reentrant)
      @prevent_gc = [] of Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)
    end

    def initialize(*, raw : Bool)
      @engine = Engine.new(raw: raw)
      @mutex = Mutex.new(:reentrant)
      @prevent_gc = [] of Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)
    end

    # --- Evaluation ---

    # Evaluates JS WITHOUT mutex protection. Use only when you already hold a lock.
    def eval!(source_code : String, flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, tag : String = "<input>") : ValueWrapper
      engine.eval_string(source_code, eval_flag: flag, etag: tag)
    end

    # Evaluates JS WITH mutex protection. Safe from any fiber.
    def eval_mutex!(source_code : String, flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, tag : String = "<input>") : ValueWrapper
      @mutex.synchronize do
        eval!(source_code, flag, tag)
      end
    end

    # --- File loading ---

    def load_file!(path : String) : ValueWrapper
      resolved = File.expand_path(path)
      raise_file_not_found(resolved) unless File.exists?(resolved)
      source_code = File.read(resolved)
      eval_mutex!(source_code, tag: resolved)
    end

    def load_module!(path : String) : ValueWrapper
      resolved = File.expand_path(path)
      raise_file_not_found(resolved) unless File.exists?(resolved)
      source_code = File.read(resolved)
      eval_mutex!(source_code, flag: QuickJS::EvalFlag::MODULE, tag: resolved)
    end

    # Auto-detects whether a file is a module or script.
    def load_auto!(path : String) : ValueWrapper
      resolved = File.expand_path(path)
      raise_file_not_found(resolved) unless File.exists?(resolved)
      source_code = File.read(resolved)
      flag = engine.context.detect_module?(source_code) ? QuickJS::EvalFlag::MODULE : QuickJS::EvalFlag::STRICT
      eval_mutex!(source_code, flag: flag, tag: resolved)
    end

    # --- Function binding ---

    # Binds a raw QuickJS C-function signature. The proc receives the raw
    # JSContext, this_val, argc, argv and must return a JSValue.
    # Use this for maximum performance / minimal GC overhead.
    def bind_raw(name : String, arg_count : Int32 = 0, &block : Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)) : Nil
      # Pin the closure so Boehm GC doesn't collect it while QuickJS holds
      # a reference to the closure data via CrystalProcedure.
      @prevent_gc << block

      @mutex.synchronize do
        js_function = engine.context.bind_crystal_function(block, name, arg_count)
        global = engine.context.global_object
        global[name] = js_function
      end
    end

    # Binds a Crystal block as a global JS function. Arguments are wrapped
    # as ValueWrappers. Return any Crystal value and it'll be converted to JS.
    def bind(name : String, arg_count : Int32 = 0, &block : Array(ValueWrapper) -> _) : Nil
      bind_raw(name, arg_count) do |ctx, _this_val, argc, argv|
        args = Array(ValueWrapper).new(argc)
        argc.times do |i|
          # DupValue so the wrapper owns its own reference
          args << ValueWrapper.new(ctx, QuickJS.DupValue(ctx, argv[i]))
        end

        result = block.call(args)
        crystal_to_js_value(ctx, result)
      end
    end

    # --- Global variables ---

    def set_global(name : String, value) : Nil
      @mutex.synchronize do
        global = engine.context.global_object
        global[name] = engine.create_value(value)
      end
    end

    def get_global(name : String) : ValueWrapper?
      @mutex.synchronize do
        global = engine.context.global_object
        value = global[name]?
        return nil if value.nil? || value.undefined?
        value
      end
    end

    # --- Function calling ---

    def call_global(name : String, arguments : Array = [] of ValueWrapper) : ValueWrapper
      @mutex.synchronize do
        global = engine.context.global_object
        func = global[name]

        wrapped_args = arguments.map do |arg|
          case arg
          when ValueWrapper then arg
          else                   engine.create_value(arg)
          end
        end

        func.call(global, wrapped_args)
      end
    end

    # --- JSON ---

    def parse_json(input : String) : ValueWrapper
      @mutex.synchronize do
        engine.context.parse_json(input)
      end
    end

    def json_stringify(obj : ValueWrapper) : String
      @mutex.synchronize do
        engine.context.json_stringify(obj)
      end
    end

    # --- Bytecode serialization ---

    # Compiles JS to bytecode without executing it.
    def compile(source_code : String, tag : String = "<compile>") : Bytes
      @mutex.synchronize do
        val = engine.context.eval_string(
          source_code,
          eval_flag: QuickJS::EvalFlag::STRICT | QuickJS::EvalFlag::COMPILE_ONLY,
          etag: tag
        )
        engine.context.write_object(val)
      end
    end

    # Loads and executes precompiled bytecode.
    def load_bytecode(bytecode : Bytes) : ValueWrapper
      @mutex.synchronize do
        obj = engine.context.read_object(bytecode)
        # JS_EvalFunction consumes the reference and executes it
        result = QuickJS.JS_EvalFunction(engine.context.to_unsafe, obj.to_unsafe)
        ValueWrapper.new(engine.context.to_unsafe, result)
      end
    end

    # --- Promise / job queue ---

    def drain_jobs : Int32
      @mutex.synchronize do
        engine.drain_jobs
      end
    end

    # --- GC ---

    def run_gc : Nil
      @mutex.synchronize do
        engine.runtime.run_gc
      end
    end

    def memory_usage : QuickJS::JSMemoryUsage
      @mutex.synchronize do
        engine.runtime.memory_usage
      end
    end

    # --- Runtime configuration ---

    def memory_limit=(limit : UInt64) : Nil
      engine.runtime.memory_limit = limit
    end

    def max_stack_size=(size : UInt64) : Nil
      engine.runtime.max_stack_size = size
    end

    def gc_threshold=(threshold : UInt64) : Nil
      engine.runtime.gc_threshold = threshold
    end

    # --- Cleanup ---

    # Explicitly shuts down the sandbox and its engine.
    # Always call this when you're done — don't rely on GC finalization.
    def close : Nil
      @prevent_gc.clear
      @engine.close
    end

    def closed? : Bool
      @engine.closed?
    end

    def finalize
      close
    end

    # --- Private helpers ---

    private def crystal_to_js_value(ctx : QuickJS::JSContext, value) : QuickJS::JSValue
      case value
      when ValueWrapper
        value.duplicate
      when String
        QuickJS.NewString(ctx, value)
      when Int32
        QuickJS.NewInt32(ctx, value)
      when Int64
        QuickJS.NewInt64(ctx, value)
      when Float64
        QuickJS.NewFloat64(ctx, value)
      when Bool
        QuickJS.NewBool(ctx, value ? 1 : 0)
      when Nil
        # Return JS undefined — construct directly, no eval needed.
        QuickJS::JSValue.new(
          u: QuickJS::ValueUnion.new(int32: 0_i32),
          tag: QuickJS::Tag::UNDEFINED.value
        )
      else
        QuickJS.NewString(ctx, value.to_s)
      end
    end

    private def raise_file_not_found(path : String) : NoReturn
      raise Exceptions::RuntimeException.new(
        message: "File not found: #{path}",
        input: path,
        eval_flag: nil,
        etag: nil,
        same_thread: true
      )
    end
  end
end
