module Medusa
  module Constants
    JS_PROP_CONFIGURABLE = (1 << 0)
    JS_PROP_WRITABLE     = (1 << 1)
    JS_PROP_ENUMERABLE   = (1 << 2)
    JS_PROP_C_W_E        = (JS_PROP_CONFIGURABLE | JS_PROP_WRITABLE | JS_PROP_ENUMERABLE)
    JS_PROP_LENGTH       = (1 << 3) # used internally in Arrays
    JS_PROP_TMASK        = (3 << 4) # mask for NORMAL, GETSET, VARREF, AUTOINIT
    JS_PROP_NORMAL       = (0 << 4)
    JS_PROP_GETSET       = (1 << 4)
    JS_GPN_STRING_MASK   = (1 << 0)
    JS_GPN_SYMBOL_MASK   = (1 << 1)
    JS_GPN_PRIVATE_MASK  = (1 << 2)
    JS_GPN_ENUM_ONLY     = (1 << 4)
    JS_GPN_SET_ENUM      = (1 << 5)
  end
end
