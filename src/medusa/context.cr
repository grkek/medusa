module Medusa
  class Context
    alias QuickJS = Binding::QuickJS

    @context : QuickJS::JSContext
    @freed : Bool = false

    # Creates a full context with std/os modules via the C++ bridge.
    def initialize(runtime : QuickJS::JSRuntime)
      @context = QuickJS.NewBuiltInContext(runtime)
    end

    # Creates a raw context — no intrinsics loaded. Call add_intrinsic_* as needed.
    def initialize(runtime : QuickJS::JSRuntime, *, raw : Bool)
      if raw
        @context = QuickJS.JS_NewContextRaw(runtime)
      else
        @context = QuickJS.NewBuiltInContext(runtime)
      end
    end

    def to_unsafe : QuickJS::JSContext
      @context
    end

    def opaque : Void*
      QuickJS.JS_GetContextOpaque(@context)
    end

    def opaque=(ptr : Void*) : Nil
      QuickJS.JS_SetContextOpaque(@context, ptr)
    end

    def runtime : QuickJS::JSRuntime
      QuickJS.JS_GetRuntime(@context)
    end

    def add_intrinsic_base_objects : Nil
      QuickJS.JS_AddIntrinsicBaseObjects(@context)
    end

    def add_intrinsic_date : Nil
      QuickJS.JS_AddIntrinsicDate(@context)
    end

    def add_intrinsic_eval : Nil
      QuickJS.JS_AddIntrinsicEval(@context)
    end

    def add_intrinsic_string_normalize : Nil
      QuickJS.JS_AddIntrinsicStringNormalize(@context)
    end

    def add_intrinsic_regexp_compiler : Nil
      QuickJS.JS_AddIntrinsicRegExpCompiler(@context)
    end

    def add_intrinsic_regexp : Nil
      QuickJS.JS_AddIntrinsicRegExp(@context)
    end

    def add_intrinsic_json : Nil
      QuickJS.JS_AddIntrinsicJSON(@context)
    end

    def add_intrinsic_proxy : Nil
      QuickJS.JS_AddIntrinsicProxy(@context)
    end

    def add_intrinsic_map_set : Nil
      QuickJS.JS_AddIntrinsicMapSet(@context)
    end

    def add_intrinsic_typed_arrays : Nil
      QuickJS.JS_AddIntrinsicTypedArrays(@context)
    end

    def add_intrinsic_promise : Nil
      QuickJS.JS_AddIntrinsicPromise(@context)
    end

    def add_intrinsic_weak_ref : Nil
      QuickJS.JS_AddIntrinsicWeakRef(@context)
    end

    # Adds all standard intrinsics at once (convenience for raw contexts).
    def add_all_intrinsics : Nil
      add_intrinsic_base_objects
      add_intrinsic_date
      add_intrinsic_eval
      add_intrinsic_string_normalize
      add_intrinsic_regexp_compiler
      add_intrinsic_regexp
      add_intrinsic_json
      add_intrinsic_proxy
      add_intrinsic_map_set
      add_intrinsic_typed_arrays
      add_intrinsic_promise
      add_intrinsic_weak_ref
    end

    def eval_string(input : String, eval_flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, etag : String = "<input>") : ValueWrapper
      value = QuickJS.JS_Eval(@context, input, input.bytesize, etag, eval_flag.value)

      if value.tag == QuickJS::Tag::EXCEPTION.value
        exception_value = QuickJS.JS_GetException(@context)
        exception = ValueWrapper.new(@context, exception_value)

        message = exception["message"]?.try(&.as_s) || "Unknown error"
        stack = exception["stack"]?.try(&.as_s)

        QuickJS.FreeValue(@context, value)

        raise Exceptions::InternalException.new(message: message, stack: stack)
      end

      ValueWrapper.new(@context, value)
    end

    def eval_this(this_obj : ValueWrapper, input : String, eval_flag : QuickJS::EvalFlag = QuickJS::EvalFlag::STRICT, etag : String = "<input>") : ValueWrapper
      value = QuickJS.JS_EvalThis(@context, this_obj.to_unsafe, input, input.bytesize, etag, eval_flag.value)

      if value.tag == QuickJS::Tag::EXCEPTION.value
        exception_value = QuickJS.JS_GetException(@context)
        exception = ValueWrapper.new(@context, exception_value)

        message = exception["message"]?.try(&.as_s) || "Unknown error"
        stack = exception["stack"]?.try(&.as_s)

        QuickJS.FreeValue(@context, value)

        raise Exceptions::InternalException.new(message: message, stack: stack)
      end

      ValueWrapper.new(@context, value)
    end

    # Detects whether a string looks like an ES module.
    def detect_module?(input : String) : Bool
      QuickJS.JS_DetectModule(input, input.bytesize) != 0
    end

    # Binds a Crystal Proc as a QuickJS function. Returns a ValueWrapper
    # for the JS function object. Each binding is independent — no shared state.
    def bind_crystal_function(procedure : Proc(QuickJS::JSContext, QuickJS::JSValue, LibC::Int, QuickJS::JSValue*, QuickJS::JSValue), name : String, length : LibC::Int) : ValueWrapper
      ValueWrapper.new(@context, QuickJS.BindCrystalFunction(@context, Glue.wrap_procedure(procedure), name, length))
    end

    # Low-level: create a QuickJS function from a raw C function pointer.
    def new_c_function2(function_pointer : QuickJS::JSCFunction, name : String, length : LibC::Int, cproto : QuickJS::CFunctionEnum = QuickJS::CFunctionEnum::GENERIC, magic : LibC::Int = 0) : ValueWrapper
      ValueWrapper.new(@context, QuickJS.JS_NewCFunction2(@context, function_pointer, name, length, cproto, magic))
    end

    def global_object : ValueWrapper
      ValueWrapper.new(@context, QuickJS.JS_GetGlobalObject(@context))
    end

    def has_exception? : Bool
      QuickJS.JS_HasException(@context) != 0
    end

    def get_exception : ValueWrapper
      ValueWrapper.new(@context, QuickJS.JS_GetException(@context))
    end

    def parse_json(input : String, filename : String = "<json>") : ValueWrapper
      value = QuickJS.JS_ParseJSON(@context, input, input.bytesize, filename)
      if value.tag == QuickJS::Tag::EXCEPTION.value
        exception_value = QuickJS.JS_GetException(@context)
        exception = ValueWrapper.new(@context, exception_value)
        message = exception["message"]?.try(&.as_s) || "JSON parse error"
        QuickJS.FreeValue(@context, value)
        raise Exceptions::InternalException.new(message: message, stack: nil)
      end
      ValueWrapper.new(@context, value)
    end

    def json_stringify(obj : ValueWrapper) : String
      # Pass JS_UNDEFINED for replacer and space
      undefined = QuickJS::JSValue.new
      result = QuickJS.JS_JSONStringify(@context, obj.to_unsafe, undefined, undefined)
      wrapper = ValueWrapper.new(@context, result)
      wrapper.as_s
    end

    def write_object(obj : ValueWrapper, flags : QuickJS::WriteObjFlag = QuickJS::WriteObjFlag::BYTECODE) : Bytes
      size = uninitialized LibC::SizeT
      ptr = QuickJS.JS_WriteObject(@context, pointerof(size), obj.to_unsafe, flags.value)
      raise "JS_WriteObject failed" if ptr.null?
      bytes = Bytes.new(ptr, size).dup # copy out of JS-managed memory
      QuickJS.js_free(@context, ptr.as(Void*))
      bytes
    end

    def read_object(buf : Bytes, flags : QuickJS::ReadObjFlag = QuickJS::ReadObjFlag::BYTECODE) : ValueWrapper
      value = QuickJS.JS_ReadObject(@context, buf.to_unsafe, buf.size, flags.value)
      if value.tag == QuickJS::Tag::EXCEPTION.value
        exception_value = QuickJS.JS_GetException(@context)
        exception = ValueWrapper.new(@context, exception_value)
        message = exception["message"]?.try(&.as_s) || "ReadObject error"
        QuickJS.FreeValue(@context, value)
        raise Exceptions::InternalException.new(message: message, stack: nil)
      end
      ValueWrapper.new(@context, value)
    end

    def self.new_class_id : QuickJS::JSClassID
      id = 0_u32
      QuickJS.JS_NewClassID(pointerof(id))
      id
    end

    def set_class_proto(class_id : QuickJS::JSClassID, obj : ValueWrapper) : Nil
      QuickJS.JS_SetClassProto(@context, class_id, obj.to_unsafe)
    end

    def get_class_proto(class_id : QuickJS::JSClassID) : ValueWrapper
      ValueWrapper.new(@context, QuickJS.JS_GetClassProto(@context, class_id))
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
      QuickJS.JS_FreeContext(@context)
    end
  end
end
