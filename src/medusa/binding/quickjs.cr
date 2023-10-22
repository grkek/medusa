module Medusa
  module Binding
    @[Link(ldflags: "#{__DIR__}/../../../bin/medusa.a #{__DIR__}/../../ext/quickjs/libquickjs.a -lc++abi")]
    lib QuickJS
      alias JSRuntime = Void*
      alias JSContext = Void*

      alias JSCFunction = Void*

      enum Tag : LibC::Int
        # all tags with a reference count are negative
        FIRST             = -11 # first negative tag
        BIG_DECIMAL       = -11
        BIG_INT           = -10
        BIG_FLOAT         =  -9
        SYMBOL            =  -8
        STRING            =  -7
        MODULE            =  -3 # used internally
        FUNCTION_BYTECODE =  -2 # used internally
        OBJECT            =  -1

        INT           = 0
        BOOL          = 1
        NULL          = 2
        UNDEFINED     = 3
        UNINITIALIZED = 4
        CATCH_OFFSET  = 5
        EXCEPTION     = 6
        FLOAT64       = 7
        # any larger tag is FLOAT64 if JS_NAN_BOXING
      end

      enum Flag : LibC::Int
        GLOBAL            = (0 << 0) # global code (default)
        MODULE            = (1 << 0) # module code
        DIRECT            = (2 << 0) # direct call (internal use)
        INDIRECT          = (3 << 0) # indirect call (internal use)
        MASK              = (3 << 0)
        STRICT            = (1 << 3) # force 'strict' mode
        STRIP             = (1 << 4) # force 'strip' mode
        COMPILE_ONLY      = (1 << 5)
        BACKTRACE_BARRIER = (1 << 6)
      end

      struct CrystalString
        pointer : LibC::Char*
        size : LibC::Int
      end

      # Container for a `Proc`
      struct CrystalProcedure
        pointer : Void*
        context : Void*
      end

      # Container for raw memory-data.  The `pointer` could be anything.
      struct CrystalSlice
        pointer : Void*
        size : LibC::Int
      end

      struct JSValue
        value_union : ValueUnion
        tag : Tag
      end

      union ValueUnion
        int32 : Int32
        float32 : Float32
        pointer : Void*
      end

      fun JS_NewRuntime : JSRuntime
      fun JS_NewContext = JS_NewBuiltInContext(runtime : JSRuntime) : JSContext

      fun JS_NewCFunctionPointer(crystalProcedure : CrystalProcedure) : JSCFunction
      fun JS_NewCFunctionDefault(ctx : JSContext, func : JSCFunction, name : LibC::Char*, length : LibC::Int) : JSValue

      fun JS_Eval(ctx : JSContext, input : LibC::Char*, input_size : LibC::Int, filename : LibC::Char*, eval_flag : LibC::Int) : JSValue

      fun JS_GetGlobalObject(ctx : JSContext) : JSValue
      fun JS_GetException(ctx : JSContext) : JSValue
      fun JS_GetPropertyStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*) : JSValue

      fun JS_ValueToCString(ctx : JSContext, val : JSValue) : LibC::Char*

      fun JS_SetPropertyStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*, val : JSValue) : LibC::Int

      fun JS_FreeValueDefault(ctx : JSContext, v : JSValue) : Void
    end
  end
end
