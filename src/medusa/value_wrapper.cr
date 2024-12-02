module Medusa
  class ValueWrapper
    alias QuickJS = Binding::QuickJS

    @context : QuickJS::JSContext
    @value : QuickJS::JSValue

    def initialize(@context : QuickJS::JSContext, value : QuickJS::JSValue)
      @value = QuickJS.DupValue(@context, value)
    end

    def initialize(@context : QuickJS::JSContext, value : Float64)
      @value = QuickJS.DupValue(@context, QuickJS.NewFloat64(@context, value))
    end

    def initialize(@context : QuickJS::JSContext, value : Int32)
      @value = QuickJS.DupValue(@context, QuickJS.NewInt32(@context, value))
    end

    def initialize(@context : QuickJS::JSContext, value : Int64)
      @value = QuickJS.DupValue(@context, QuickJS.NewInt64(@context, value))
    end

    def initialize(@context : QuickJS::JSContext, value : String)
      @value = QuickJS.DupValue(@context, QuickJS.NewString(@context, value))
    end

    def initialize(@context : QuickJS::JSContext, value : Bool)
      @value = QuickJS.DupValue(@context, QuickJS.NewBool(@context, value))
    end

    def initialize(@context : QuickJS::JSContext, value : Hash(String, JSON::Any))
      @value = QuickJS.DupValue(@context, QuickJS.JS_NewObject(@context))

      value.each do |key, inner_value|
        self.[key] = from_json(inner_value)
      end
    end

    def initialize(@context : QuickJS::JSContext, values : Array(JSON::Any))
      @value = QuickJS.DupValue(@context, QuickJS.JS_NewArray(@context))

      values.each_with_index do |value, index|
        QuickJS.JS_SetPropertyUint32(@context, @value, index.to_u32, from_json(value).to_unsafe, Constants::JS_PROP_C_W_E)
      end
    end

    def [](index : Int32) : ValueWrapper
      raise Exception.new("Can not fetch a property at #{index}, because it is not an array") unless @value.tag == QuickJS::Tag::OBJECT
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyUint32(@context, @value, index.to_u32))

      raise Exception.new("QuickJS returned an undefined value #{value} at #{index}") if QuickJS.IsUndefined(value)
      value
    end

    def []?(index : Int32) : ValueWrapper
      raise Exception.new("Can not fetch a property at #{index}, because it is not an array") unless @value.tag == QuickJS::Tag::OBJECT
      ValueWrapper.new(@context, QuickJS.JS_GetPropertyUint32(@context, @value, index.to_u32))
    end

    def []=(index : Int32, value : ValueWrapper) : ValueWrapper
    end

    def [](key : String) : ValueWrapper
      raise Exception.new("Can not fetch a property #{key} from #{@value}, because it is not an object") unless @value.tag == QuickJS::Tag::OBJECT
      value = ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @value, key))

      raise Exception.new("QuickJS returned an undefined value #{value} for #{key}") if QuickJS.IsUndefined(value)
      value
    end

    def []?(key : String) : ValueWrapper
      raise Exception.new("Can not fetch a property #{key} from #{@value}, because it is not an object") unless @value.tag == QuickJS::Tag::OBJECT
      ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @value, key))
    end

    def []=(key : String, value : ValueWrapper) : ValueWrapper
      raise Exception.new("Can not set a property #{key} to #{@value}, because it is not an object") unless @value.tag == QuickJS::Tag::OBJECT
      return self unless QuickJS.JS_SetPropertyStr(@context, @value, key, value) == -1
      raise Exception.new("Unable to set property #{key} on #{@value} as #{value}")
    end

    def ==(other : self) : Bool
      QuickJS.JS_StrictEq(@context, other.to_unsafe, @value)
    end

    def undefined? : Bool
      QuickJS.IsUndefined(@value)
    end

    def as_s : String
      c_string = QuickJS.ToCString(@context, @value)
      value = String.new(c_string)

      QuickJS.JS_FreeCString(@context, c_string)

      value
    end

    def as_bool : Bool
      QuickJS.JS_ToBool(@context, @value) ? true : false
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

    def as_a : Array(JSON::Any)
      array = [] of JSON::Any

      length = ValueWrapper.new(@context, QuickJS.JS_GetPropertyStr(@context, @value, "length"))

      length.as_i.times do |index|
        value = QuickJS.JS_GetPropertyUint32(@context, @value, index.to_u32)

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

      if QuickJS.JS_GetOwnPropertyNames(@context, pointerof(properties), out plen, @value, Constants::JS_GPN_STRING_MASK | Constants::JS_GPN_ENUM_ONLY) == 0
        plen.times do |index|
          property_enum = properties[index]
          property_name = String.new(QuickJS.JS_AtomToCString(@context, property_enum.atom))
          value = QuickJS.GetProperty(@context, @value, property_enum.atom)

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
          end
        end
      end

      hash
    end

    def to_unsafe : QuickJS::JSValue
      @value
    end

    def finalize
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
