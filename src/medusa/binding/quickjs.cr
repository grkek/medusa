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

      struct JSPropertyEnum
        enumerable? : Bool
        atom : LibC::UInt
      end

      fun JS_NewRuntime : JSRuntime
      fun JS_NewObject(ctx : JSContext) : JSValue
      fun JS_NewArray(ctx : JSContext) : JSValue

      fun JS_RunGC(rt : JSRuntime) : Void

      # Every time you change threads you must execute this otherwise a stack overflow error is thrown.
      fun JS_UpdateStackTop(rt : JSRuntime) : Void

      ### Begin helper functions
      fun NewBuiltInContext(rt : JSRuntime) : JSContext
      fun NewCFunctionPointer(crystal_procedure : CrystalProcedure) : JSCFunction
      fun NewCFunction(ctx : JSContext, func : JSCFunction, name : LibC::Char*, length : LibC::Int) : JSValue
      fun NewFloat64(ctx : JSContext, f : Float64) : JSValue
      fun NewString(ctx : JSContext, str : LibC::Char*) : JSValue
      fun NewInt32(ctx : JSContext, val : LibC::Int) : JSValue
      fun NewInt64(ctx : JSContext, val : LibC::LongLong) : JSValue
      fun NewBool(ctx : JSContext, val : Bool) : JSValue

      fun IsUndefined(val : JSValue) : Bool

      fun DupValue(ctx : JSContext, val : JSValue) : JSValue
      fun FreeValue(ctx : JSContext, val : JSValue) : Void

      fun ToCString(ctx : JSContext, val : JSValue) : LibC::Char*

      fun GetProperty(ctx : JSContext, this_obj : JSValue, prop : LibC::UInt) : JSValue
      ### End helper functions

      fun JS_Eval(ctx : JSContext, input : LibC::Char*, input_size : LibC::Int, filename : LibC::Char*, eval_flag : LibC::Int) : JSValue
      fun JS_Call(ctx : JSContext, func_obj : JSValue, this_obj : JSValue, argc : LibC::Int, argv : JSValue*) : JSValue

      fun JS_WriteObject(ctx : JSContext, psize : LibC::SizeT*, obj : JSValue, flags : LibC::Int) : LibC::Char*
      fun JS_ReadObject(ctx : JSContext, buf : LibC::Char*, buf_len : LibC::SizeT, flags : LibC::Int) : JSValue

      fun JS_IsError(ctx : JSContext, val : JSValue) : Bool
      fun JS_IsArray(ctx : JSContext, val : JSValue) : Bool

      fun JS_StrictEq(ctx : JSContext, op1 : JSValue, op2 : JSValue) : Bool

      fun JS_AtomToCString(ctx : JSContext, atom : LibC::UInt) : LibC::Char*
      fun JS_ToBool(ctx : JSContext, val : JSValue) : LibC::Int
      fun JS_ToInt32(ctx : JSContext, pres : Int32*, val : JSValue) : LibC::Int
      fun JS_ToInt64(ctx : JSContext, pres : Int64*, val : JSValue) : LibC::Int
      fun JS_ToFloat64(ctx : JSContext, pres : Float64*, val : JSValue) : LibC::Int

      fun JS_SetPropertyStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*, val : JSValue) : LibC::Int
      fun JS_SetPropertyUint32(ctx : JSContext, this_obj : JSValue, idx : LibC::UInt, val : JSValue, flags : LibC::Int) : LibC::Int

      fun JS_GetGlobalObject(ctx : JSContext) : JSValue
      fun JS_GetException(ctx : JSContext) : JSValue

      fun JS_GetOwnPropertyNames(ctx : JSContext, ptab : JSPropertyEnum**, plen : LibC::UInt*, obj : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_GetArrayBuffer(ctx : JSContext, psize : LibC::SizeT*, obj : JSValue) : LibC::Char*
      fun JS_GetPropertyUint32(ctx : JSContext, this_obj : JSValue, idx : LibC::UInt) : JSValue
      fun JS_GetPropertyStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*) : JSValue

      fun JS_FreeRuntime(rt : JSRuntime) : Void
      fun JS_FreeContext(ctx : JSContext) : Void
      fun JS_FreeCString(ctx : JSContext, val : LibC::Char*) : Void
    end
  end
end
