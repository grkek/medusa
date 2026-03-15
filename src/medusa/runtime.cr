module Medusa
  class Runtime
    alias QuickJS = Binding::QuickJS

    @runtime : QuickJS::JSRuntime
    @freed : Bool = false

    def initialize
      @runtime = QuickJS.JS_NewRuntime
    end

    def to_unsafe : QuickJS::JSRuntime
      @runtime
    end

    def memory_limit=(limit : UInt64) : Nil
      QuickJS.JS_SetMemoryLimit(@runtime, limit)
    end

    def gc_threshold=(threshold : UInt64) : Nil
      QuickJS.JS_SetGCThreshold(@runtime, threshold)
    end

    def max_stack_size=(size : UInt64) : Nil
      QuickJS.JS_SetMaxStackSize(@runtime, size)
    end

    def update_stack_top : Nil
      QuickJS.JS_UpdateStackTop(@runtime)
    end

    def info=(info : String) : Nil
      QuickJS.JS_SetRuntimeInfo(@runtime, info)
    end

    def opaque : Void*
      QuickJS.JS_GetRuntimeOpaque(@runtime)
    end

    def opaque=(ptr : Void*) : Nil
      QuickJS.JS_SetRuntimeOpaque(@runtime, ptr)
    end

    def run_gc : Nil
      QuickJS.JS_RunGC(@runtime)
    end

    def live_object?(obj : QuickJS::JSValue) : Bool
      QuickJS.JS_IsLiveObject(@runtime, obj) != 0
    end

    def memory_usage : QuickJS::JSMemoryUsage
      usage = QuickJS::JSMemoryUsage.new
      QuickJS.JS_ComputeMemoryUsage(@runtime, pointerof(usage))
      usage
    end

    def job_pending? : Bool
      QuickJS.JS_IsJobPending(@runtime) != 0
    end

    # Executes one pending job. Returns {success, context} where success
    # is true if a job was executed, false if none pending.
    # Raises on JS exception during job execution (returns < 0).
    def execute_pending_job : {Bool, QuickJS::JSContext}
      ctx = Pointer(Void).null.as(QuickJS::JSContext)
      ret = QuickJS.JS_ExecutePendingJob(@runtime, pointerof(ctx))

      if ret < 0
        raise Exceptions::RuntimeException.new(
          message: "Exception during pending job execution",
          input: "<job>",
          eval_flag: nil,
          etag: nil,
          same_thread: true
        )
      end

      {ret > 0, ctx}
    end

    # Drains all pending jobs. Returns the number of jobs executed.
    def drain_jobs : Int32
      count = 0
      loop do
        success, _ = execute_pending_job
        break unless success
        count += 1
      end
      count
    end

    def strip_info=(flags : QuickJS::StripFlag) : Nil
      QuickJS.JS_SetStripInfo(@runtime, flags.value)
    end

    def strip_info : Int32
      QuickJS.JS_GetStripInfo(@runtime)
    end

    def can_block=(val : Bool) : Nil
      QuickJS.JS_SetCanBlock(@runtime, val ? 1 : 0)
    end

    # Enables file-based ES module loading. After calling this, all contexts
    # on this runtime can use `import` / `export` with file paths.
    # Relative paths are resolved from the importing module's directory.
    # This runs entirely in C — no Crystal closures cross the FFI boundary.
    def setup_module_loader : Nil
      QuickJS.SetupFileModuleLoader(@runtime)
    end

    def freed? : Bool
      @freed
    end

    def mark_freed! : Nil
      @freed = true
    end

    def finalize : Nil
      return if @freed
      @freed = true
      QuickJS.JS_FreeRuntime(@runtime)
    end
  end
end
