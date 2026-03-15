module Medusa
  class Sandbox
    Log = ::Log.for(self)

    alias QuickJS = Binding::QuickJS

    getter engine : Engine

    @mutex : Mutex
    @prevent_gc : Array(Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue))

    def initialize
      @engine = Engine.new
      @mutex = Mutex.new(:reentrant)
      @prevent_gc = [] of Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)
      Log.info { "Sandbox initialized" }
    end

    def initialize(*, raw : Bool)
      @engine = Engine.new(raw: raw)
      @mutex = Mutex.new(:reentrant)
      @prevent_gc = [] of Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)
      Log.info { "Sandbox initialized (raw: #{raw})" }
    end

    # JS keyword highlighting for log output
    private JS_KEYWORDS = %w[
      function var const let return if else for while do switch case break
      continue new delete typeof instanceof in of this true false null undefined
      try catch finally throw class extends import export default from async await
      Object Array JSON Math String Number Boolean
    ]

    private def format_js(source : String) : String
      lines = source.strip.split('\n')

      String.build do |io|
        lines.each_with_index do |line, i|
          formatted = line
            .gsub(/("(?:[^"\\]|\\.)*")/) { |m| "\e[33m#{m}\e[0m" }                          # strings → yellow
            .gsub(/('(?:[^'\\]|\\.)*')/) { |m| "\e[33m#{m}\e[0m" }                           # strings → yellow
            .gsub(/(\/\/.*)$/) { |m| "\e[90m#{m}\e[0m" }                                     # comments → gray
            .gsub(/\b(\d+\.?\d*)\b/) { |m| "\e[36m#{m}\e[0m" }                               # numbers → cyan
            .gsub(/\b(#{JS_KEYWORDS.join("|")})\b/) { |m| "\e[35m#{m}\e[0m" }                # keywords → magenta

          line_num = (i + 1).to_s.rjust(3)
          io << "  \e[90m#{line_num} │\e[0m #{formatted}\n"
        end
      end
    end

    def eval!(source_code : String, flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, tag : String = "<input>") : ValueWrapper
      Log.debug {
        header = "\e[1meval!\e[0m #{source_code.bytesize} bytes, tag: \e[36m#{tag}\e[0m"

        String.build do |io|
          io << header << "\n"
          io << format_js(source_code)
        end
      }
      engine.eval_string(source_code, eval_flag: flag, etag: tag)
    end

    def eval_mutex!(source_code : String, flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, tag : String = "<input>") : ValueWrapper
      @mutex.synchronize do
        eval!(source_code, flag, tag)
      end
    end

    def load_file!(path : String) : ValueWrapper
      resolved = File.expand_path(path)
      Log.info { "Loading file: #{resolved}" }
      raise_file_not_found(resolved) unless File.exists?(resolved)
      source_code = File.read(resolved)
      eval_mutex!(source_code, tag: resolved)
    end

    def load_module!(path : String) : ValueWrapper
      resolved = File.expand_path(path)
      Log.info { "Loading module: #{resolved}" }
      raise_file_not_found(resolved) unless File.exists?(resolved)
      source_code = File.read(resolved)
      eval_mutex!(source_code, flag: QuickJS::EvalFlag::MODULE, tag: resolved)
    end

    def load_auto!(path : String) : ValueWrapper
      resolved = File.expand_path(path)
      raise_file_not_found(resolved) unless File.exists?(resolved)
      source_code = File.read(resolved)
      is_module = engine.context.detect_module?(source_code)
      flag = is_module ? QuickJS::EvalFlag::MODULE : QuickJS::EvalFlag::STRICT
      Log.info { "Loading #{is_module ? "module" : "script"}: #{resolved}" }
      eval_mutex!(source_code, flag: flag, tag: resolved)
    end

    def bind_raw(name : String, arg_count : Int32 = 0, &block : Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue)) : Nil
      Log.debug { "bind_raw: #{name} (#{arg_count} args)" }
      @prevent_gc << block

      @mutex.synchronize do
        js_function = engine.context.bind_crystal_function(block, name, arg_count)
        global = engine.context.global_object
        global[name] = js_function
      end
    end

    def bind(name : String, arg_count : Int32 = 0, &block : Array(ValueWrapper) -> _) : Nil
      Log.debug { "bind: #{name} (#{arg_count} args)" }
      bind_raw(name, arg_count) do |ctx, _this_val, argc, argv|
        args = Array(ValueWrapper).new(argc)
        argc.times do |i|
          args << ValueWrapper.new(ctx, QuickJS.DupValue(ctx, argv[i]))
        end

        result = block.call(args)
        crystal_to_js_value(ctx, result)
      end
    end

    def set_global(name : String, value) : Nil
      Log.debug { "set_global: #{name}" }
      @mutex.synchronize do
        global = engine.context.global_object
        global[name] = engine.create_value(value)
      end
    end

    def get_global(name : String) : ValueWrapper?
      Log.debug { "get_global: #{name}" }
      @mutex.synchronize do
        global = engine.context.global_object
        value = global[name]?
        return nil if value.nil? || value.undefined?
        value
      end
    end

    def call_global(name : String, arguments : Array = [] of ValueWrapper) : ValueWrapper
      Log.debug { "call_global: #{name} (#{arguments.size} args)" }
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

    def parse_json(input : String) : ValueWrapper
      Log.debug { "parse_json (#{input.bytesize} bytes)" }
      @mutex.synchronize do
        engine.context.parse_json(input)
      end
    end

    def json_stringify(obj : ValueWrapper) : String
      Log.debug { "json_stringify" }
      @mutex.synchronize do
        engine.context.json_stringify(obj)
      end
    end

    def compile(source_code : String, tag : String = "<compile>") : Bytes
      Log.info { "Compiling to bytecode (#{source_code.bytesize} bytes, tag: #{tag})" }
      @mutex.synchronize do
        val = engine.context.eval_string(
          source_code,
          eval_flag: QuickJS::EvalFlag::STRICT | QuickJS::EvalFlag::COMPILE_ONLY,
          etag: tag
        )
        bytecode = engine.context.write_object(val)
        Log.debug { "Compiled: #{source_code.bytesize} bytes source → #{bytecode.size} bytes bytecode" }
        bytecode
      end
    end

    def load_bytecode(bytecode : Bytes) : ValueWrapper
      Log.info { "Loading bytecode (#{bytecode.size} bytes)" }
      @mutex.synchronize do
        obj = engine.context.read_object(bytecode)
        result = QuickJS.JS_EvalFunction(engine.context.to_unsafe, obj.to_unsafe)
        ValueWrapper.new(engine.context.to_unsafe, result)
      end
    end

    def drain_jobs : Int32
      @mutex.synchronize do
        count = engine.drain_jobs
        Log.debug { "Drained #{count} pending job(s)" } if count > 0
        count
      end
    end

    def run_gc : Nil
      Log.debug { "Running GC" }
      @mutex.synchronize do
        engine.runtime.run_gc
      end
    end

    def memory_usage : QuickJS::JSMemoryUsage
      @mutex.synchronize do
        engine.runtime.memory_usage
      end
    end

    def memory_limit=(limit : UInt64) : Nil
      Log.debug { "Memory limit set: #{limit} bytes" }
      engine.runtime.memory_limit = limit
    end

    def max_stack_size=(size : UInt64) : Nil
      Log.debug { "Max stack size set: #{size} bytes" }
      engine.runtime.max_stack_size = size
    end

    def gc_threshold=(threshold : UInt64) : Nil
      Log.debug { "GC threshold set: #{threshold} bytes" }
      engine.runtime.gc_threshold = threshold
    end

    def close : Nil
      Log.info { "Closing sandbox (#{@prevent_gc.size} pinned closure(s))" }
      @prevent_gc.clear
      @engine.close
    end

    def closed? : Bool
      @engine.closed?
    end

    def finalize
      close
    end

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
        QuickJS::JSValue.new(
          u: QuickJS::ValueUnion.new(int32: 0_i32),
          tag: QuickJS::Tag::UNDEFINED.value
        )
      else
        QuickJS.NewString(ctx, value.to_s)
      end
    end

    private def raise_file_not_found(path : String) : NoReturn
      Log.error { "File not found: #{path}" }
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
