module Medusa
  class ValueWrapper
    alias QuickJS = Binding::QuickJS

    @context : QuickJS::JSContext

    @value : QuickJS::JSValue
    @reference : QuickJS::JSValue

    def initialize(@context : QuickJS::JSContext, value : QuickJS::JSValue)
      # Duplicate the value to ensure proper reference counting.
      @value = value
      @reference = QuickJS.DupValue(@context, value)
    end

    def initialize(@context : QuickJS::JSContext, value : Float64)
      @value = QuickJS.NewFloat64(@context, value)
      @reference = QuickJS.DupValue(@context, @value)
    end

    def initialize(@context : QuickJS::JSContext, value : Int32)
      @value = QuickJS.NewInt32(@context, value)
      @reference = QuickJS.DupValue(@context, @value)
    end

    def initialize(@context : QuickJS::JSContext, value : Int64)
      @value = QuickJS.NewInt64(@context, value)
      @reference = QuickJS.DupValue(@context, @value)
    end

    def initialize(@context : QuickJS::JSContext, value : String)
      @value = QuickJS.NewString(@context, value)
      @reference = QuickJS.DupValue(@context, @value)
    end

    def initialize(@context : QuickJS::JSContext, value : Bool)
      @value = QuickJS.NewBool(@context, value)
      @reference = QuickJS.DupValue(@context, @value)
    end

    def initialize(@context : QuickJS::JSContext, value : Hash(String, JSON::Any))
      @value = QuickJS.JS_NewObject(@context)
      @reference = QuickJS.DupValue(@context, @value)

      value.each do |key, inner_value|
        self.[key] = from_json(inner_value)
      end
    end

    def initialize(@context : QuickJS::JSContext, values : Array(JSON::Any))
      @value = QuickJS.JS_NewArray(@context)
      @reference = QuickJS.DupValue(@context, @value)

      values.each_with_index do |value, index|
        QuickJS.JS_SetPropertyUint32(@context, @reference, index.to_u32, from_json(value).to_unsafe, Constants::JS_PROP_C_W_E)
      end
    end

    def [](index : Int32) : ValueWrapper
      raise Exception.new("Can not fetch a property at #{index}, because it is not an array") unless @reference.tag == QuickJS::Tag::OBJECT
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyUint32(@context, @reference, index.to_u32))

      raise Exception.new("QuickJS returned an undefined value #{value} at #{index}") if QuickJS.IsUndefined(value)
      value
    end

    def []?(index : Int32) : ValueWrapper
      raise Exception.new("Can not fetch a property at #{index}, because it is not an array") unless @reference.tag == QuickJS::Tag::OBJECT
      ValueWrapper.new(@context, QuickJS.JS_GetPropertyUint32(@context, @reference, index.to_u32))
    end

    def []=(index : Int32, value : ValueWrapper) : ValueWrapper
    end

    def [](key : String) : ValueWrapper
      raise Exception.new("Can not fetch a property #{key} from #{@reference}, because it is not an object") unless @reference.tag == QuickJS::Tag::OBJECT
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @reference, key))

      raise Exception.new("QuickJS returned an undefined value #{value} for #{key}") if QuickJS.IsUndefined(value)
      value
    end

    def []?(key : String) : ValueWrapper
      raise Exception.new("Can not fetch a property #{key} from #{@reference}, because it is not an object") unless @reference.tag == QuickJS::Tag::OBJECT
      ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @reference, key))
    end

    def []=(key : String, value : ValueWrapper) : ValueWrapper
      raise Exception.new("Can not set a property #{key} to #{@reference}, because it is not an object") unless @reference.tag == QuickJS::Tag::OBJECT
      return self unless QuickJS.JS_SetPropertyStr(@context, @reference, key, value) == -1
      raise Exception.new("Unable to set property #{key} on #{@reference} as #{value}")
    end

    def ==(other : self) : Bool
      QuickJS.JS_StrictEq(@context, other.to_unsafe, @reference)
    end

    def undefined? : Bool
      QuickJS.IsUndefined(@reference)
    end

    def as_s : String
      c_string = QuickJS.ToCString(@context, @reference)
      value = String.new(c_string)

      QuickJS.JS_FreeCString(@context, c_string)

      value
    end

    def as_bool : Bool
      QuickJS.JS_ToBool(@context, @reference) ? true : false
    end

    def as_i : Int32
      QuickJS.JS_ToInt32(@context, out value, @reference)
      value
    end

    def as_i64 : Int64
      QuickJS.JS_ToInt64(@context, out value, @reference)
      value
    end

    def as_f64 : Float64
      QuickJS.JS_ToFloat64(@context, out value, @reference)
      value
    end

    def as_a : Array(JSON::Any)
      array = [] of JSON::Any

      length = ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @reference, "length"))

      length.as_i.times do |index|
        value = QuickJS.JS_GetPropertyUint32(@context, @reference, index.to_u32)

        case value.tag
        when QuickJS::Tag::OBJECT
          if QuickJS.JS_IsArray(@context, value)
            array.concat(ValueWrapper.new(@context, value).as_a)
          else
            array.push(JSON::Any.new(ValueWrapper.new(@context, value).as_h))
          end
        when QuickJS::Tag::STRING
          array.push(JSON::Any.new(ValueWrapper.new(@context, value).as_s))
        when QuickJS::Tag::INT
          array.push(JSON::Any.new(ValueWrapper.new(@context, value).as_i))
        when QuickJS::Tag::BOOL
          array.push(JSON::Any.new(ValueWrapper.new(@context, value).as_bool))
        when QuickJS::Tag::FLOAT64
          array.push(JSON::Any.new(ValueWrapper.new(@context, value).as_f64))
        when QuickJS::Tag::NULL
          array.push(JSON::Any.new(nil))
        end
      end

      array
    end

    def as_h : Hash(String, JSON::Any)
      hash = {} of String => JSON::Any
      properties = Pointer(QuickJS::JSPropertyEnum).null

      if QuickJS.JS_GetOwnPropertyNames(@context, pointerof(properties), out plen, @reference, Constants::JS_GPN_STRING_MASK | Constants::JS_GPN_ENUM_ONLY) == 0
        plen.times do |index|
          property_enum = properties[index]
          c_string = QuickJS.JS_AtomToCString(@context, property_enum.atom)
          property_name = String.new(c_string)

          QuickJS.JS_FreeCString(@context, c_string)

          value = QuickJS.GetProperty(@context, @reference, property_enum.atom)

          case value.tag
          when QuickJS::Tag::OBJECT
            if QuickJS.JS_IsArray(@context, value)
              hash[property_name] = JSON::Any.new(ValueWrapper.new(@context, value).as_a)
            else
              hash[property_name] = JSON::Any.new(ValueWrapper.new(@context, value).as_h)
            end
          when QuickJS::Tag::STRING
            hash[property_name] = JSON::Any.new(ValueWrapper.new(@context, value).as_s)
          when QuickJS::Tag::INT
            hash[property_name] = JSON::Any.new(ValueWrapper.new(@context, value).as_i)
          when QuickJS::Tag::BOOL
            hash[property_name] = JSON::Any.new(ValueWrapper.new(@context, value).as_bool)
          when QuickJS::Tag::FLOAT64
            hash[property_name] = JSON::Any.new(ValueWrapper.new(@context, value).as_f64)
          when QuickJS::Tag::NULL
            hash[property_name] = JSON::Any.new(nil)
          else
          end
        end
      end

      hash
    end

    def to_unsafe : QuickJS::JSValue
      @reference
    end

    def finalize
      if @reference != @value
        QuickJS.FreeValue(@context, @reference)
      end

      QuickJS.FreeValue(@context, @value)
    end

    def from_json(value : JSON::Any) : ValueWrapper
      case value
      when .as_i?
        ValueWrapper.new(@context, value.as_i)
      when .as_i64?
        ValueWrapper.new(@context, value.as_i64)
      when .as_bool?
        ValueWrapper.new(@context, value.as_bool)
      when .as_f?
        ValueWrapper.new(@context, value.as_f)
      when .as_s?
        ValueWrapper.new(@context, value.as_s)
      when .as_h?
        ValueWrapper.new(@context, value.as_h)
      when .as_a?
        ValueWrapper.new(@context, value.as_a)
      else
        raise Exceptions::TypeException.new(value)
      end
    end
  end
end
