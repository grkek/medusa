module Medusa
  class ValueWrapper
    alias QuickJS = Binding::QuickJS

    @context : QuickJS::JSContext
    @value : QuickJS::JSValue
    @freed : Bool = false

    def initialize(@context : QuickJS::JSContext, value : QuickJS::JSValue)
      @value = value
    end

    def initialize(@context : QuickJS::JSContext, value : Float64)
      @value = QuickJS.NewFloat64(@context, value)
    end

    def initialize(@context : QuickJS::JSContext, value : Int32)
      @value = QuickJS.NewInt32(@context, value)
    end

    def initialize(@context : QuickJS::JSContext, value : Int64)
      @value = QuickJS.NewInt64(@context, value)
    end

    def initialize(@context : QuickJS::JSContext, value : String)
      @value = QuickJS.NewString(@context, value)
    end

    def initialize(@context : QuickJS::JSContext, value : Bool)
      @value = QuickJS.NewBool(@context, value ? 1 : 0)
    end

    def initialize(@context : QuickJS::JSContext, value : Hash(String, JSON::Any))
      @value = QuickJS.JS_NewObject(@context)

      value.each do |key, inner_value|
        self.[key] = from_json(inner_value)
      end
    end

    def initialize(@context : QuickJS::JSContext, values : Array(JSON::Any))
      @value = QuickJS.JS_NewArray(@context)

      values.each_with_index do |value, index|
        QuickJS.JS_SetPropertyUint32(@context, @value, index.to_u32, from_json(value).to_unsafe)
      end
    end

    private def tag : Int64
      @value.tag
    end

    private def object_tag? : Bool
      tag == QuickJS::Tag::OBJECT.value
    end

    def [](index : Int32) : ValueWrapper
      raise Exception.new("Cannot fetch property at #{index}: not an object") unless object_tag?
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyUint32(@context, @value, index.to_u32))
      raise Exception.new("Undefined value at index #{index}") if QuickJS.IsUndefined(value.to_unsafe)
      value
    end

    def []?(index : Int32) : ValueWrapper?
      return nil unless object_tag?
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyUint32(@context, @value, index.to_u32))
      return nil if QuickJS.IsUndefined(value.to_unsafe)
      value
    end

    def []=(index : Int32, value : ValueWrapper) : ValueWrapper
      raise Exception.new("Cannot set property at #{index}: not an object") unless object_tag?
      duped = QuickJS.DupValue(@context, value.to_unsafe)
      if QuickJS.JS_SetPropertyUint32(@context, @value, index.to_u32, duped) < 0
        QuickJS.FreeValue(@context, duped)
        raise Exception.new("Failed to set property at index #{index}")
      end
      value
    end

    def [](key : String) : ValueWrapper
      raise Exception.new("Cannot fetch property '#{key}': not an object") unless object_tag?
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @value, key))
      raise Exception.new("Undefined value for key '#{key}'") if QuickJS.IsUndefined(value.to_unsafe)
      value
    end

    def []?(key : String) : ValueWrapper?
      return nil unless object_tag?
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @value, key))
      return nil if QuickJS.IsUndefined(value.to_unsafe)
      value
    end

    def []=(key : String, value : ValueWrapper) : ValueWrapper
      raise Exception.new("Cannot set property '#{key}': not an object") unless object_tag?
      duped = QuickJS.DupValue(@context, value.to_unsafe)
      if QuickJS.JS_SetPropertyStr(@context, @value, key, duped) < 0
        QuickJS.FreeValue(@context, duped)
        raise Exception.new("Failed to set property '#{key}'")
      end
      value
    end

    def get_property(atom : QuickJS::JSAtom) : ValueWrapper
      ValueWrapper.new(@context, QuickJS.GetProperty(@context, @value, atom))
    end

    def has_property?(atom : QuickJS::JSAtom) : Bool
      QuickJS.JS_HasProperty(@context, @value, atom) > 0
    end

    def delete_property(atom : QuickJS::JSAtom, flags : Int32 = 0) : Bool
      QuickJS.JS_DeleteProperty(@context, @value, atom, flags) > 0
    end

    def prototype : ValueWrapper
      ValueWrapper.new(@context, QuickJS.JS_GetPrototype(@context, @value))
    end

    def prototype=(proto : ValueWrapper) : Nil
      QuickJS.JS_SetPrototype(@context, @value, proto.to_unsafe)
    end

    def define_property_value(atom : QuickJS::JSAtom, val : ValueWrapper, flags : Int32 = Constants::JS_PROP_C_W_E) : Nil
      duped = QuickJS.DupValue(@context, val.to_unsafe)
      if QuickJS.JS_DefinePropertyValue(@context, @value, atom, duped, flags) < 0
        QuickJS.FreeValue(@context, duped)
        raise Exception.new("Failed to define property")
      end
    end

    def ==(other : self) : Bool
      QuickJS.JS_StrictEq(@context, @value, other.to_unsafe) != 0
    end

    def same_value?(other : self) : Bool
      QuickJS.JS_SameValue(@context, @value, other.to_unsafe) != 0
    end

    def undefined? : Bool
      QuickJS.IsUndefined(@value)
    end

    def null? : Bool
      tag == QuickJS::Tag::NULL.value
    end

    def exception? : Bool
      QuickJS.IsException(@value)
    end

    def object? : Bool
      object_tag?
    end

    def string? : Bool
      tag == QuickJS::Tag::STRING.value || tag == QuickJS::Tag::STRING_ROPE.value
    end

    def int? : Bool
      tag == QuickJS::Tag::INT.value
    end

    def bool? : Bool
      tag == QuickJS::Tag::BOOL.value
    end

    def float64? : Bool
      tag == QuickJS::Tag::FLOAT64.value
    end

    def short_big_int? : Bool
      tag == QuickJS::Tag::SHORT_BIG_INT.value
    end

    def number? : Bool
      int? || float64? || short_big_int?
    end

    def array? : Bool
      object_tag? && QuickJS.JS_IsArray(@context, @value) != 0
    end

    def function? : Bool
      object_tag? && QuickJS.JS_IsFunction(@context, @value) != 0
    end

    def error? : Bool
      object_tag? && QuickJS.JS_IsError(@context, @value) != 0
    end

    def constructor? : Bool
      object_tag? && QuickJS.JS_IsConstructor(@context, @value) != 0
    end

    def as_s : String
      c_string = QuickJS.ToCString(@context, @value)
      value = String.new(c_string)
      QuickJS.JS_FreeCString(@context, c_string)
      value
    end

    def as_bool : Bool
      QuickJS.JS_ToBool(@context, @value) != 0
    end

    def as_i : Int32
      QuickJS.JS_ToInt32(@context, out value, @value)
      value
    end

    def as_i64 : Int64
      QuickJS.JS_ToInt64(@context, out value, @value)
      value
    end

    def as_f64 : Float64
      QuickJS.JS_ToFloat64(@context, out value, @value)
      value
    end

    def as_big_int64 : Int64
      QuickJS.JS_ToBigInt64(@context, out value, @value)
      value
    end

    def as_a : Array(JSON::Any)
      array = [] of JSON::Any

      length_val = QuickJS.JS_GetPropertyStr(@context, @value, "length")
      length_wrapper = ValueWrapper.new(@context, length_val)
      len = length_wrapper.as_i

      len.times do |index|
        js_val = QuickJS.JS_GetPropertyUint32(@context, @value, index.to_u32)
        array.push(js_value_to_json_any(js_val))
      end

      array
    end

    def as_h : Hash(String, JSON::Any)
      hash = {} of String => JSON::Any
      properties = Pointer(QuickJS::JSPropertyEnum).null

      ret = QuickJS.JS_GetOwnPropertyNames(
        @context, pointerof(properties), out plen, @value,
        Constants::JS_GPN_STRING_MASK | Constants::JS_GPN_ENUM_ONLY
      )

      if ret == 0
        plen.times do |index|
          property_enum = properties[index]
          c_string = QuickJS.AtomToCString(@context, property_enum.atom)
          property_name = String.new(c_string)
          QuickJS.JS_FreeCString(@context, c_string)

          js_val = QuickJS.GetProperty(@context, @value, property_enum.atom)
          hash[property_name] = js_value_to_json_any(js_val)
        end

        QuickJS.JS_FreePropertyEnum(@context, properties, plen) unless properties.null?
      end

      hash
    end

    def to_json_any : JSON::Any
      js_value_to_json_any(@value)
    end

    def call(this_obj : ValueWrapper, args : Array(ValueWrapper) = [] of ValueWrapper) : ValueWrapper
      argc = args.size
      argv = argc > 0 ? Pointer(QuickJS::JSValue).malloc(argc) : Pointer(QuickJS::JSValue).null

      args.each_with_index do |arg, i|
        argv[i] = QuickJS.DupValue(@context, arg.to_unsafe)
      end

      result = QuickJS.JS_Call(@context, @value, this_obj.to_unsafe, argc, argv)

      argc.times { |i| QuickJS.FreeValue(@context, argv[i]) }

      wrapper = ValueWrapper.new(@context, result)
      if QuickJS.IsException(result)
        exception_value = QuickJS.JS_GetException(@context)
        js_exception = ValueWrapper.new(@context, exception_value)
        message = js_exception["message"]?.try(&.as_s) || "Unknown JS error"
        stack = js_exception["stack"]?.try(&.as_s)
        raise Exceptions::InternalException.new(message: message, stack: stack.try(&.strip))
      end

      wrapper
    end

    def call_constructor(args : Array(ValueWrapper) = [] of ValueWrapper) : ValueWrapper
      argc = args.size
      argv = argc > 0 ? Pointer(QuickJS::JSValue).malloc(argc) : Pointer(QuickJS::JSValue).null

      args.each_with_index do |arg, i|
        argv[i] = QuickJS.DupValue(@context, arg.to_unsafe)
      end

      result = QuickJS.JS_CallConstructor(@context, @value, argc, argv)
      argc.times { |i| QuickJS.FreeValue(@context, argv[i]) }

      ValueWrapper.new(@context, result)
    end

    def set_opaque(ptr : Void*) : Nil
      QuickJS.JS_SetOpaque(@value, ptr)
    end

    def get_opaque(class_id : QuickJS::JSClassID) : Void*
      QuickJS.JS_GetOpaque(@value, class_id)
    end

    def get_opaque2(class_id : QuickJS::JSClassID) : Void*
      QuickJS.JS_GetOpaque2(@context, @value, class_id)
    end

    def to_unsafe : QuickJS::JSValue
      @value
    end

    def duplicate : QuickJS::JSValue
      QuickJS.DupValue(@context, @value)
    end

    def to_s(io : IO) : Nil
      case
      when undefined? then io << "undefined"
      when null?      then io << "null"
      when bool?      then io << as_bool
      when int?       then io << as_i
      when float64?   then io << as_f64
      when string?    then io << as_s
      when array?     then io << as_a
      when object?    then io << as_h
      else                 io << "[JSValue tag=#{tag}]"
      end
    end

    def free! : Nil
      return if @freed
      @freed = true
      QuickJS.FreeValue(@context, @value)
    end
    # GC finalizer. We intentionally do NOT call FreeValue here.
    #
    # Boehm GC runs finalizers in non-deterministic order and can trigger
    # them during allocation inside other callbacks. If this ValueWrapper
    # belongs to a sandbox that has already been closed, the context pointer
    # is dangling and FreeValue would segfault.
    #
    # The trade-off: JSValues with refcounts leak until their Engine is closed,
    # at which point FreeContextAndRuntime drops everything in bulk. During
    # normal long-lived operation (like a GUI event loop), this is fine —
    # QuickJS's own GC handles internal object collection. The Crystal-side
    # wrappers only hold extra refs that prevent QuickJS from collecting;
    # once the engine shuts down, everything is freed.
    def finalize
      # No-op. Prevent use-after-free on dangling context pointers.
    end

    private def js_value_to_json_any(val : QuickJS::JSValue) : JSON::Any
      val_tag = val.tag

      case val_tag
      when QuickJS::Tag::OBJECT.value
        if QuickJS.JS_IsArray(@context, val) != 0
          JSON::Any.new(ValueWrapper.new(@context, val).as_a)
        else
          JSON::Any.new(ValueWrapper.new(@context, val).as_h)
        end
      when QuickJS::Tag::STRING.value, QuickJS::Tag::STRING_ROPE.value
        JSON::Any.new(ValueWrapper.new(@context, val).as_s)
      when QuickJS::Tag::INT.value
        JSON::Any.new(ValueWrapper.new(@context, val).as_i64)
      when QuickJS::Tag::BOOL.value
        JSON::Any.new(ValueWrapper.new(@context, val).as_bool)
      when QuickJS::Tag::FLOAT64.value
        JSON::Any.new(ValueWrapper.new(@context, val).as_f64)
      when QuickJS::Tag::SHORT_BIG_INT.value
        JSON::Any.new(ValueWrapper.new(@context, val).as_i64)
      when QuickJS::Tag::NULL.value
        JSON::Any.new(nil)
      when QuickJS::Tag::UNDEFINED.value
        JSON::Any.new(nil)
      else
        JSON::Any.new(nil)
      end
    end

    def from_json(value : JSON::Any) : ValueWrapper
      case value.raw
      when Int64
        ValueWrapper.new(@context, value.as_i64)
      when Float64
        ValueWrapper.new(@context, value.as_f)
      when Bool
        ValueWrapper.new(@context, value.as_bool)
      when String
        ValueWrapper.new(@context, value.as_s)
      when Hash
        ValueWrapper.new(@context, value.as_h)
      when Array
        ValueWrapper.new(@context, value.as_a)
      when Nil
        # JS_NULL = { .u.int32 = 0, .tag = JS_TAG_NULL (2) }
        null_val = QuickJS::JSValue.new(
          u: QuickJS::ValueUnion.new(int32: 0_i32),
          tag: QuickJS::Tag::NULL.value
        )
        ValueWrapper.new(@context, null_val)
      else
        raise Exceptions::TypeException.new(value)
      end
    end
  end
end
