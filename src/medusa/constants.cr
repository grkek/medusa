module Medusa
  module Constants
    alias QuickJS = Binding::QuickJS

    # Property flags (convenience integers for raw FFI calls)
    JS_PROP_CONFIGURABLE = QuickJS::PropFlag::CONFIGURABLE.value
    JS_PROP_WRITABLE     = QuickJS::PropFlag::WRITABLE.value
    JS_PROP_ENUMERABLE   = QuickJS::PropFlag::ENUMERABLE.value
    JS_PROP_C_W_E        = JS_PROP_CONFIGURABLE | JS_PROP_WRITABLE | JS_PROP_ENUMERABLE
    JS_PROP_LENGTH       = QuickJS::PropFlag::LENGTH.value
    JS_PROP_TMASK        = (3 << 4)
    JS_PROP_NORMAL       = QuickJS::PropFlag::NORMAL.value
    JS_PROP_GETSET       = QuickJS::PropFlag::GETSET.value
    JS_PROP_THROW        = QuickJS::PropFlag::THROW.value
    JS_PROP_THROW_STRICT = QuickJS::PropFlag::THROW_STRICT.value

    # GetOwnPropertyNames flags
    JS_GPN_STRING_MASK   = QuickJS::GPNFlag::STRING_MASK.value
    JS_GPN_SYMBOL_MASK   = QuickJS::GPNFlag::SYMBOL_MASK.value
    JS_GPN_PRIVATE_MASK  = QuickJS::GPNFlag::PRIVATE_MASK.value
    JS_GPN_ENUM_ONLY     = QuickJS::GPNFlag::ENUM_ONLY.value
    JS_GPN_SET_ENUM      = QuickJS::GPNFlag::SET_ENUM.value

    # Null atom
    JS_ATOM_NULL = 0_u32

    # Invalid class ID
    JS_INVALID_CLASS_ID = 0_u32

    # Default stack size
    JS_DEFAULT_STACK_SIZE = 1024 * 1024
  end
end
