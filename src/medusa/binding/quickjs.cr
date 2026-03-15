module Medusa
  module Binding
    # Link against the C++ bridge for closure wrapping, QuickJS itself, and Boehm GC.
    # The C++ bridge (medusa.a) is only needed for NewCFunctionPointer and NewBuiltInContext.
    # Everything else calls QuickJS directly.
    @[Link(ldflags: "#{__DIR__}/../../../bin/medusa.a #{__DIR__}/../../ext/quickjs/libquickjs.a -lc++abi -lgc")]
    lib QuickJS
      # ---------------------------------------------------------------------------
      # Opaque handles
      # ---------------------------------------------------------------------------
      alias JSRuntime = Void*
      alias JSContext = Void*
      alias JSCFunction = Void*
      alias JSModuleDef = Void*
      alias JSClassID = LibC::UInt
      alias JSAtom = LibC::UInt

      # ---------------------------------------------------------------------------
      # Tags — must match quickjs.h exactly.
      #
      # NOTE: The upstream QuickJS tags differ from what was previously declared.
      # BIG_DECIMAL, BIG_FLOAT, STRING_ROPE are absent or renumbered in newer
      # QuickJS versions. These match the header you provided.
      # ---------------------------------------------------------------------------
      enum Tag : Int64
        FIRST             =  -9
        BIG_INT           =  -9
        SYMBOL            =  -8
        STRING            =  -7
        STRING_ROPE       =  -6
        MODULE            =  -3
        FUNCTION_BYTECODE =  -2
        OBJECT            =  -1
        INT               =   0
        BOOL              =   1
        NULL              =   2
        UNDEFINED         =   3
        UNINITIALIZED     =   4
        CATCH_OFFSET      =   5
        EXCEPTION         =   6
        SHORT_BIG_INT     =   7
        FLOAT64           =   8
      end

      # ---------------------------------------------------------------------------
      # Eval flags — JS_EVAL_TYPE_* and JS_EVAL_FLAG_*
      # ---------------------------------------------------------------------------
      @[Flags]
      enum EvalFlag : LibC::Int
        GLOBAL            = (0 << 0)
        MODULE            = (1 << 0)
        DIRECT            = (2 << 0)
        INDIRECT          = (3 << 0)
        # TYPE_MASK       = (3 << 0) — use .value & 3 if needed
        STRICT            = (1 << 3)
        COMPILE_ONLY      = (1 << 5)
        BACKTRACE_BARRIER = (1 << 6)
        ASYNC             = (1 << 7)
      end

      # Keep the old name around for backward compatibility
      alias Flag = EvalFlag

      # ---------------------------------------------------------------------------
      # Property flags — JS_PROP_*
      # ---------------------------------------------------------------------------
      @[Flags]
      enum PropFlag : LibC::Int
        CONFIGURABLE      = (1 << 0)
        WRITABLE          = (1 << 1)
        ENUMERABLE        = (1 << 2)
        LENGTH            = (1 << 3)
        # TMASK           = (3 << 4)
        NORMAL            = (0 << 4)
        GETSET            = (1 << 4)
        VARREF            = (2 << 4)
        AUTOINIT          = (3 << 4)
        HAS_CONFIGURABLE  = (1 << 8)
        HAS_WRITABLE      = (1 << 9)
        HAS_ENUMERABLE    = (1 << 10)
        HAS_GET           = (1 << 11)
        HAS_SET           = (1 << 12)
        HAS_VALUE         = (1 << 13)
        THROW             = (1 << 14)
        THROW_STRICT      = (1 << 15)
        NO_EXOTIC         = (1 << 16)
      end

      # ---------------------------------------------------------------------------
      # GetOwnPropertyNames flags — JS_GPN_*
      # ---------------------------------------------------------------------------
      @[Flags]
      enum GPNFlag : LibC::Int
        STRING_MASK  = (1 << 0)
        SYMBOL_MASK  = (1 << 1)
        PRIVATE_MASK = (1 << 2)
        ENUM_ONLY    = (1 << 4)
        SET_ENUM     = (1 << 5)
      end

      # ---------------------------------------------------------------------------
      # WriteObject / ReadObject flags
      # ---------------------------------------------------------------------------
      @[Flags]
      enum WriteObjFlag : LibC::Int
        BYTECODE  = (1 << 0)
        BSWAP     = (1 << 1)
        SAB       = (1 << 2)
        REFERENCE = (1 << 3)
      end

      @[Flags]
      enum ReadObjFlag : LibC::Int
        BYTECODE  = (1 << 0)
        ROM_DATA  = (1 << 1)
        SAB       = (1 << 2)
        REFERENCE = (1 << 3)
      end

      # ---------------------------------------------------------------------------
      # Strip info flags
      # ---------------------------------------------------------------------------
      @[Flags]
      enum StripFlag : LibC::Int
        SOURCE = (1 << 0)
        DEBUG  = (1 << 1)
      end

      # ---------------------------------------------------------------------------
      # Promise state
      # ---------------------------------------------------------------------------
      enum PromiseState : LibC::Int
        PENDING   = 0
        FULFILLED = 1
        REJECTED  = 2
      end

      # ---------------------------------------------------------------------------
      # C function prototype enum
      # ---------------------------------------------------------------------------
      enum CFunctionEnum : LibC::Int
        GENERIC                    = 0
        GENERIC_MAGIC              = 1
        CONSTRUCTOR                = 2
        CONSTRUCTOR_MAGIC          = 3
        CONSTRUCTOR_OR_FUNC        = 4
        CONSTRUCTOR_OR_FUNC_MAGIC  = 5
        F_F                        = 6
        F_F_F                      = 7
        GETTER                     = 8
        SETTER                     = 9
        GETTER_MAGIC               = 10
        SETTER_MAGIC               = 11
        ITERATOR_NEXT              = 12
      end

      # ---------------------------------------------------------------------------
      # TypedArray enum
      # ---------------------------------------------------------------------------
      enum TypedArrayEnum : LibC::Int
        UINT8C     = 0
        INT8       = 1
        UINT8      = 2
        INT16      = 3
        UINT16     = 4
        INT32      = 5
        UINT32     = 6
        BIG_INT64  = 7
        BIG_UINT64 = 8
        FLOAT16    = 9
        FLOAT32    = 10
        FLOAT64    = 11
      end

      # ---------------------------------------------------------------------------
      # Value types — matches the non-NAN_BOXING 64-bit layout from quickjs.h
      # ---------------------------------------------------------------------------
      union ValueUnion
        int32 : Int32
        float64 : Float64
        short_big_int : Int64
        ptr : Void*
      end

      struct JSValue
        u : ValueUnion
        tag : Int64
      end

      # ---------------------------------------------------------------------------
      # Property enumeration
      # ---------------------------------------------------------------------------
      struct JSPropertyEnum
        is_enumerable : LibC::Int  # JS_BOOL = int
        atom : JSAtom
      end

      # ---------------------------------------------------------------------------
      # Memory usage
      # ---------------------------------------------------------------------------
      struct JSMemoryUsage
        malloc_size : Int64
        malloc_limit : Int64
        memory_used_size : Int64
        malloc_count : Int64
        memory_used_count : Int64
        atom_count : Int64
        atom_size : Int64
        str_count : Int64
        str_size : Int64
        obj_count : Int64
        obj_size : Int64
        prop_count : Int64
        prop_size : Int64
        shape_count : Int64
        shape_size : Int64
        js_func_count : Int64
        js_func_size : Int64
        js_func_code_size : Int64
        js_func_pc2line_count : Int64
        js_func_pc2line_size : Int64
        c_func_count : Int64
        array_count : Int64
        fast_array_count : Int64
        fast_array_elements : Int64
        binary_object_count : Int64
        binary_object_size : Int64
      end

      # ---------------------------------------------------------------------------
      # Malloc state/functions (for custom allocators)
      # ---------------------------------------------------------------------------
      struct JSMallocState
        malloc_count : LibC::SizeT
        malloc_size : LibC::SizeT
        malloc_limit : LibC::SizeT
        opaque : Void*
      end

      # ---------------------------------------------------------------------------
      # Crystal<->C++ interop structs (used by medusa.cpp bridge only)
      # ---------------------------------------------------------------------------
      struct CrystalString
        pointer : LibC::Char*
        size : LibC::Int
      end

      struct CrystalProcedure
        pointer : Void*
        context : Void*
      end

      struct CrystalSlice
        pointer : Void*
        size : LibC::Int
      end

      # =========================================================================
      # C++ BRIDGE FUNCTIONS (from medusa.cpp)
      # Only needed for operations that require C++ (closure wrapping, etc.)
      # =========================================================================
      fun NewBuiltInContext(rt : JSRuntime) : JSContext
      fun BindCrystalFunction(ctx : JSContext, crystal_procedure : CrystalProcedure, name : LibC::Char*, length : LibC::Int) : JSValue
      fun NewFloat64(ctx : JSContext, f : Float64) : JSValue
      fun NewString(ctx : JSContext, str : LibC::Char*) : JSValue
      fun NewInt32(ctx : JSContext, val : LibC::Int) : JSValue
      fun NewInt64(ctx : JSContext, val : LibC::LongLong) : JSValue
      fun NewBool(ctx : JSContext, val : LibC::Int) : JSValue
      fun IsUndefined(val : JSValue) : Bool
      fun IsException(val : JSValue) : Bool
      fun DupValue(ctx : JSContext, val : JSValue) : JSValue
      fun FreeValue(ctx : JSContext, val : JSValue) : Void
      fun ToCString(ctx : JSContext, val : JSValue) : LibC::Char*
      fun GetProperty(ctx : JSContext, this_obj : JSValue, prop : JSAtom) : JSValue
      fun AtomToCString(ctx : JSContext, atom : JSAtom) : LibC::Char*
      fun SetupFileModuleLoader(rt : JSRuntime) : Void
      fun FreeContextAndRuntime(ctx : JSContext, rt : JSRuntime, has_std_handlers : LibC::Int) : Void

      # =========================================================================
      # DIRECT QUICKJS BINDINGS
      # These call QuickJS functions directly — no C++ intermediary.
      # =========================================================================

      # Runtime lifecycle
      fun JS_NewRuntime : JSRuntime
      fun JS_FreeRuntime(rt : JSRuntime) : Void
      fun JS_SetRuntimeInfo(rt : JSRuntime, info : LibC::Char*) : Void
      fun JS_SetMemoryLimit(rt : JSRuntime, limit : LibC::SizeT) : Void
      fun JS_SetGCThreshold(rt : JSRuntime, gc_threshold : LibC::SizeT) : Void
      fun JS_SetMaxStackSize(rt : JSRuntime, stack_size : LibC::SizeT) : Void
      fun JS_UpdateStackTop(rt : JSRuntime) : Void
      fun JS_GetRuntimeOpaque(rt : JSRuntime) : Void*
      fun JS_SetRuntimeOpaque(rt : JSRuntime, opaque : Void*) : Void
      fun JS_RunGC(rt : JSRuntime) : Void
      fun JS_IsLiveObject(rt : JSRuntime, obj : JSValue) : LibC::Int
      fun JS_ComputeMemoryUsage(rt : JSRuntime, s : JSMemoryUsage*) : Void
      fun JS_SetStripInfo(rt : JSRuntime, flags : LibC::Int) : Void
      fun JS_GetStripInfo(rt : JSRuntime) : LibC::Int
      fun JS_SetCanBlock(rt : JSRuntime, can_block : LibC::Int) : Void

      # Context lifecycle
      fun JS_NewContext(rt : JSRuntime) : JSContext
      fun JS_FreeContext(ctx : JSContext) : Void
      fun JS_DupContext(ctx : JSContext) : JSContext
      fun JS_GetContextOpaque(ctx : JSContext) : Void*
      fun JS_SetContextOpaque(ctx : JSContext, opaque : Void*) : Void
      fun JS_GetRuntime(ctx : JSContext) : JSRuntime

      # Minimal / raw context
      fun JS_NewContextRaw(rt : JSRuntime) : JSContext
      fun JS_AddIntrinsicBaseObjects(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicDate(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicEval(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicStringNormalize(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicRegExpCompiler(ctx : JSContext) : Void
      fun JS_AddIntrinsicRegExp(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicJSON(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicProxy(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicMapSet(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicTypedArrays(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicPromise(ctx : JSContext) : LibC::Int
      fun JS_AddIntrinsicWeakRef(ctx : JSContext) : LibC::Int

      # Class/prototype support
      fun JS_NewClassID(pclass_id : JSClassID*) : JSClassID
      fun JS_GetClassID(v : JSValue) : JSClassID
      fun JS_IsRegisteredClass(rt : JSRuntime, class_id : JSClassID) : LibC::Int
      fun JS_SetClassProto(ctx : JSContext, class_id : JSClassID, obj : JSValue) : Void
      fun JS_GetClassProto(ctx : JSContext, class_id : JSClassID) : JSValue

      # Eval
      fun JS_Eval(ctx : JSContext, input : LibC::Char*, input_len : LibC::SizeT, filename : LibC::Char*, eval_flags : LibC::Int) : JSValue
      fun JS_EvalThis(ctx : JSContext, this_obj : JSValue, input : LibC::Char*, input_len : LibC::SizeT, filename : LibC::Char*, eval_flags : LibC::Int) : JSValue
      fun JS_EvalFunction(ctx : JSContext, fun_obj : JSValue) : JSValue
      fun JS_DetectModule(input : LibC::Char*, input_len : LibC::SizeT) : LibC::Int

      # Calling
      fun JS_Call(ctx : JSContext, func_obj : JSValue, this_obj : JSValue, argc : LibC::Int, argv : JSValue*) : JSValue
      fun JS_Invoke(ctx : JSContext, this_val : JSValue, atom : JSAtom, argc : LibC::Int, argv : JSValue*) : JSValue
      fun JS_CallConstructor(ctx : JSContext, func_obj : JSValue, argc : LibC::Int, argv : JSValue*) : JSValue
      fun JS_CallConstructor2(ctx : JSContext, func_obj : JSValue, new_target : JSValue, argc : LibC::Int, argv : JSValue*) : JSValue

      # Global object
      fun JS_GetGlobalObject(ctx : JSContext) : JSValue

      # Object creation
      fun JS_NewObject(ctx : JSContext) : JSValue
      fun JS_NewObjectProtoClass(ctx : JSContext, proto : JSValue, class_id : JSClassID) : JSValue
      fun JS_NewObjectClass(ctx : JSContext, class_id : LibC::Int) : JSValue
      fun JS_NewObjectProto(ctx : JSContext, proto : JSValue) : JSValue
      fun JS_NewArray(ctx : JSContext) : JSValue
      fun JS_NewDate(ctx : JSContext, epoch_ms : Float64) : JSValue

      # Type checking
      fun JS_IsFunction(ctx : JSContext, val : JSValue) : LibC::Int
      fun JS_IsConstructor(ctx : JSContext, val : JSValue) : LibC::Int
      fun JS_SetConstructorBit(ctx : JSContext, func_obj : JSValue, val : LibC::Int) : LibC::Int
      fun JS_IsArray(ctx : JSContext, val : JSValue) : LibC::Int
      fun JS_IsError(ctx : JSContext, val : JSValue) : LibC::Int
      fun JS_IsInstanceOf(ctx : JSContext, val : JSValue, obj : JSValue) : LibC::Int

      # Value creation (direct QuickJS — these are static inline in the hea
      #     but we also have them via the C++ bridge above for when the compiler
      #     doesn't inline them across the FFI boundary) ---
      # The C++ bridge versions (NewFloat64, NewString, etc.) handle null checks.
      # Use the direct ones when you've already validated the context.

      # Equality
      fun JS_StrictEq(ctx : JSContext, op1 : JSValue, op2 : JSValue) : LibC::Int
      fun JS_SameValue(ctx : JSContext, op1 : JSValue, op2 : JSValue) : LibC::Int
      fun JS_SameValueZero(ctx : JSContext, op1 : JSValue, op2 : JSValue) : LibC::Int

      # Value conversion
      fun JS_ToBool(ctx : JSContext, val : JSValue) : LibC::Int
      fun JS_ToInt32(ctx : JSContext, pres : Int32*, val : JSValue) : LibC::Int
      fun JS_ToInt64(ctx : JSContext, pres : Int64*, val : JSValue) : LibC::Int
      fun JS_ToIndex(ctx : JSContext, plen : UInt64*, val : JSValue) : LibC::Int
      fun JS_ToFloat64(ctx : JSContext, pres : Float64*, val : JSValue) : LibC::Int
      fun JS_ToBigInt64(ctx : JSContext, pres : Int64*, val : JSValue) : LibC::Int
      fun JS_ToInt64Ext(ctx : JSContext, pres : Int64*, val : JSValue) : LibC::Int

      # String creation/conversion
      fun JS_NewStringLen(ctx : JSContext, str : LibC::Char*, len : LibC::SizeT) : JSValue
      fun JS_NewAtomString(ctx : JSContext, str : LibC::Char*) : JSValue
      fun JS_ToString(ctx : JSContext, val : JSValue) : JSValue
      fun JS_ToPropertyKey(ctx : JSContext, val : JSValue) : JSValue
      fun JS_ToCStringLen2(ctx : JSContext, plen : LibC::SizeT*, val : JSValue, cesu8 : LibC::Int) : LibC::Char*
      fun JS_FreeCString(ctx : JSContext, ptr : LibC::Char*) : Void

      # Atom support
      fun JS_NewAtomLen(ctx : JSContext, str : LibC::Char*, len : LibC::SizeT) : JSAtom
      fun JS_NewAtom(ctx : JSContext, str : LibC::Char*) : JSAtom
      fun JS_NewAtomUInt32(ctx : JSContext, n : LibC::UInt) : JSAtom
      fun JS_DupAtom(ctx : JSContext, v : JSAtom) : JSAtom
      fun JS_FreeAtom(ctx : JSContext, v : JSAtom) : Void
      fun JS_FreeAtomRT(rt : JSRuntime, v : JSAtom) : Void
      fun JS_AtomToValue(ctx : JSContext, atom : JSAtom) : JSValue
      fun JS_AtomToString(ctx : JSContext, atom : JSAtom) : JSValue
      fun JS_ValueToAtom(ctx : JSContext, val : JSValue) : JSAtom

      # Reference counting
      # Note: JS_DupValue and JS_FreeValue are static inline in quickjs.h.
      # We bind them through the C++ bridge (DupValue/FreeValue above) which
      # adds null-context checks. For hot paths where you've validated the
      # context, you can call the __JS_FreeValue non-inline variant directly.
      fun __JS_FreeValue(ctx : JSContext, v : JSValue) : Void
      fun __JS_FreeValueRT(rt : JSRuntime, v : JSValue) : Void

      # Property access
      fun JS_GetPropertyStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*) : JSValue
      fun JS_GetPropertyUint32(ctx : JSContext, this_obj : JSValue, idx : LibC::UInt) : JSValue
      fun JS_GetPropertyInternal(ctx : JSContext, obj : JSValue, prop : JSAtom, receiver : JSValue, throw_ref_error : LibC::Int) : JSValue

      fun JS_SetPropertyStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*, val : JSValue) : LibC::Int
      fun JS_SetPropertyUint32(ctx : JSContext, this_obj : JSValue, idx : LibC::UInt, val : JSValue) : LibC::Int
      fun JS_SetPropertyInt64(ctx : JSContext, this_obj : JSValue, idx : Int64, val : JSValue) : LibC::Int
      fun JS_SetPropertyInternal(ctx : JSContext, obj : JSValue, prop : JSAtom, val : JSValue, this_obj : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_HasProperty(ctx : JSContext, this_obj : JSValue, prop : JSAtom) : LibC::Int

      fun JS_DeleteProperty(ctx : JSContext, obj : JSValue, prop : JSAtom, flags : LibC::Int) : LibC::Int
      fun JS_SetPrototype(ctx : JSContext, obj : JSValue, proto_val : JSValue) : LibC::Int
      fun JS_GetPrototype(ctx : JSContext, val : JSValue) : JSValue
      fun JS_IsExtensible(ctx : JSContext, obj : JSValue) : LibC::Int
      fun JS_PreventExtensions(ctx : JSContext, obj : JSValue) : LibC::Int

      fun JS_DefineProperty(ctx : JSContext, this_obj : JSValue, prop : JSAtom, val : JSValue, getter : JSValue, setter : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_DefinePropertyValue(ctx : JSContext, this_obj : JSValue, prop : JSAtom, val : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_DefinePropertyValueUint32(ctx : JSContext, this_obj : JSValue, idx : LibC::UInt, val : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_DefinePropertyValueStr(ctx : JSContext, this_obj : JSValue, prop : LibC::Char*, val : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_DefinePropertyGetSet(ctx : JSContext, this_obj : JSValue, prop : JSAtom, getter : JSValue, setter : JSValue, flags : LibC::Int) : LibC::Int

      # Property enumeration
      fun JS_GetOwnPropertyNames(ctx : JSContext, ptab : JSPropertyEnum**, plen : LibC::UInt*, obj : JSValue, flags : LibC::Int) : LibC::Int
      fun JS_FreePropertyEnum(ctx : JSContext, tab : JSPropertyEnum*, len : LibC::UInt) : Void
      # JS_GetOwnProperty returns a descriptor — requires JSPropertyDescriptor struct
      # which has JSValue fields; we bind it but leave descriptor creation to higher-level code.

      # Opaque data
      fun JS_SetOpaque(obj : JSValue, opaque : Void*) : Void
      fun JS_GetOpaque(obj : JSValue, class_id : JSClassID) : Void*
      fun JS_GetOpaque2(ctx : JSContext, obj : JSValue, class_id : JSClassID) : Void*
      fun JS_GetAnyOpaque(obj : JSValue, class_id : JSClassID*) : Void*

      # Exception handling
      fun JS_Throw(ctx : JSContext, obj : JSValue) : JSValue
      fun JS_SetUncatchableException(ctx : JSContext, flag : LibC::Int) : Void
      fun JS_GetException(ctx : JSContext) : JSValue
      fun JS_HasException(ctx : JSContext) : LibC::Int
      fun JS_NewError(ctx : JSContext) : JSValue
      fun JS_ThrowSyntaxError(ctx : JSContext, fmt : LibC::Char*, ...) : JSValue
      fun JS_ThrowTypeError(ctx : JSContext, fmt : LibC::Char*, ...) : JSValue
      fun JS_ThrowReferenceError(ctx : JSContext, fmt : LibC::Char*, ...) : JSValue
      fun JS_ThrowRangeError(ctx : JSContext, fmt : LibC::Char*, ...) : JSValue
      fun JS_ThrowInternalError(ctx : JSContext, fmt : LibC::Char*, ...) : JSValue
      fun JS_ThrowOutOfMemory(ctx : JSContext) : JSValue

      # JSON
      fun JS_ParseJSON(ctx : JSContext, buf : LibC::Char*, buf_len : LibC::SizeT, filename : LibC::Char*) : JSValue
      fun JS_ParseJSON2(ctx : JSContext, buf : LibC::Char*, buf_len : LibC::SizeT, filename : LibC::Char*, flags : LibC::Int) : JSValue
      fun JS_JSONStringify(ctx : JSContext, obj : JSValue, replacer : JSValue, space0 : JSValue) : JSValue

      # ArrayBuffer
      fun JS_NewArrayBuffer(ctx : JSContext, buf : UInt8*, len : LibC::SizeT, free_func : Void*, opaque : Void*, is_shared : LibC::Int) : JSValue
      fun JS_NewArrayBufferCopy(ctx : JSContext, buf : UInt8*, len : LibC::SizeT) : JSValue
      fun JS_DetachArrayBuffer(ctx : JSContext, obj : JSValue) : Void
      fun JS_GetArrayBuffer(ctx : JSContext, psize : LibC::SizeT*, obj : JSValue) : UInt8*

      # TypedArrays
      fun JS_NewTypedArray(ctx : JSContext, argc : LibC::Int, argv : JSValue*, array_type : TypedArrayEnum) : JSValue
      fun JS_GetTypedArrayBuffer(ctx : JSContext, obj : JSValue, pbyte_offset : LibC::SizeT*, pbyte_length : LibC::SizeT*, pbytes_per_element : LibC::SizeT*) : JSValue

      # Promises
      fun JS_NewPromiseCapability(ctx : JSContext, resolving_funcs : JSValue*) : JSValue
      fun JS_PromiseState(ctx : JSContext, promise : JSValue) : PromiseState
      fun JS_PromiseResult(ctx : JSContext, promise : JSValue) : JSValue

      # BigInt
      fun JS_NewBigInt64(ctx : JSContext, v : Int64) : JSValue
      fun JS_NewBigUint64(ctx : JSContext, v : UInt64) : JSValue

      # Job queue
      fun JS_IsJobPending(rt : JSRuntime) : LibC::Int
      fun JS_ExecutePendingJob(rt : JSRuntime, pctx : JSContext*) : LibC::Int

      # Object serialization
      fun JS_WriteObject(ctx : JSContext, psize : LibC::SizeT*, obj : JSValue, flags : LibC::Int) : UInt8*
      fun JS_WriteObject2(ctx : JSContext, psize : LibC::SizeT*, obj : JSValue, flags : LibC::Int, psab_tab : UInt8***, psab_tab_len : LibC::SizeT*) : UInt8*
      fun JS_ReadObject(ctx : JSContext, buf : UInt8*, buf_len : LibC::SizeT, flags : LibC::Int) : JSValue

      # Module support
      fun JS_ResolveModule(ctx : JSContext, obj : JSValue) : LibC::Int
      fun JS_GetScriptOrModuleName(ctx : JSContext, n_stack_levels : LibC::Int) : JSAtom
      fun JS_LoadModule(ctx : JSContext, basename : LibC::Char*, filename : LibC::Char*) : JSValue
      fun JS_GetImportMeta(ctx : JSContext, m : JSModuleDef) : JSValue
      fun JS_GetModuleName(ctx : JSContext, m : JSModuleDef) : JSAtom
      fun JS_GetModuleNamespace(ctx : JSContext, m : JSModuleDef) : JSValue
      fun JS_SetModuleExport(ctx : JSContext, m : JSModuleDef, export_name : LibC::Char*, val : JSValue) : LibC::Int
      fun JS_AddModuleExport(ctx : JSContext, m : JSModuleDef, name_str : LibC::Char*) : LibC::Int
      fun JS_SetModulePrivateValue(ctx : JSContext, m : JSModuleDef, val : JSValue) : LibC::Int
      fun JS_GetModulePrivateValue(ctx : JSContext, m : JSModuleDef) : JSValue

      # C function definition (direct)
      fun JS_NewCFunction2(ctx : JSContext, func : JSCFunction, name : LibC::Char*, length : LibC::Int, cproto : CFunctionEnum, magic : LibC::Int) : JSValue
      fun JS_NewCFunctionData(ctx : JSContext, func : Void*, length : LibC::Int, magic : LibC::Int, data_len : LibC::Int, data : JSValue*) : JSValue
      fun JS_SetConstructor(ctx : JSContext, func_obj : JSValue, proto : JSValue) : LibC::Int
      fun JS_SetPropertyFunctionList(ctx : JSContext, obj : JSValue, tab : Void*, len : LibC::Int) : LibC::Int

      # Interrupt handler
      fun JS_SetInterruptHandler(rt : JSRuntime, cb : Void*, opaque : Void*) : Void

      # Module loader
      fun JS_SetModuleLoaderFunc(rt : JSRuntime, module_normalize : Void*, module_loader : Void*, opaque : Void*) : Void

      # IsHTMLDDA
      fun JS_SetIsHTMLDDA(ctx : JSContext, obj : JSValue) : Void

      # Debug printing
      fun JS_PrintValue(ctx : JSContext, write_func : Void*, write_opaque : Void*, val : JSValue, options : Void*) : Void
      fun JS_PrintValueRT(rt : JSRuntime, write_func : Void*, write_opaque : Void*, val : JSValue, options : Void*) : Void

      # QuickJS-libc (std/os modules)
      fun js_std_init_handlers(rt : JSRuntime) : Void
      fun js_init_module_std(ctx : JSContext, module_name : LibC::Char*) : JSModuleDef
      fun js_init_module_os(ctx : JSContext, module_name : LibC::Char*) : JSModuleDef

      # Memory allocation (QuickJS-managed)
      fun js_malloc(ctx : JSContext, size : LibC::SizeT) : Void*
      fun js_free(ctx : JSContext, ptr : Void*) : Void
      fun js_realloc(ctx : JSContext, ptr : Void*, size : LibC::SizeT) : Void*
      fun js_mallocz(ctx : JSContext, size : LibC::SizeT) : Void*
      fun js_strdup(ctx : JSContext, str : LibC::Char*) : LibC::Char*

      fun js_malloc_rt(rt : JSRuntime, size : LibC::SizeT) : Void*
      fun js_free_rt(rt : JSRuntime, ptr : Void*) : Void
      fun js_realloc_rt(rt : JSRuntime, ptr : Void*, size : LibC::SizeT) : Void*

      # Boehm GC (used by Crystal runtime)
      fun GC_MALLOC = GC_malloc(size : LibC::SizeT) : Void*
      fun GC_INIT = GC_init : Void
    end
  end
end
