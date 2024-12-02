#include "medusa_helpers.hpp"
#include "quickjs/quickjs.h"
#include "quickjs/quickjs-libc.h"

extern "C" JSContext *NewBuiltInContext(JSRuntime *rt)
{
  JSContext *ctx = JS_NewContext(rt);

  js_std_init_handlers(rt);

  js_init_module_std(ctx, "std");
  js_init_module_os(ctx, "os");

  return ctx;
}

extern "C" JSCFunction *NewCFunctionPointer(CrystalProcedure<JSValue, JSContext *, JSValue, int, JSValue *> crystalProcedure)
{
  return fnptr<JSCFunction>([crystalProcedure](JSContext *ctx, JSValue thisValue, int argc, JSValue *argv)
                            { return crystalProcedure(ctx, thisValue, argc, argv); });
}

extern "C" JSValue NewCFunction(JSContext *ctx, JSCFunction *func, const char *name, int length)
{
  return JS_NewCFunction(ctx, func, name, length);
}

extern "C" JSValue NewFloat64(JSContext *ctx, double d)
{
  return JS_NewFloat64(ctx, d);
}

extern "C" JSValue NewString(JSContext *ctx, const char *str)
{
  return JS_NewString(ctx, str);
}

extern "C" JSValue NewInt32(JSContext *ctx, int32_t val)
{
  return JS_NewInt32(ctx, val);
}

extern "C" JSValue NewInt64(JSContext *ctx, int64_t val)
{
  return JS_NewInt64(ctx, val);
}

extern "C" JSValue NewBool(JSContext *ctx, int val)
{
  return JS_NewBool(ctx, val);
}

extern "C" bool IsUndefined(JSValue val)
{
  return JS_IsUndefined(val);
}

extern "C" void FreeValue(JSContext *ctx, JSValue val)
{
  JS_FreeValue(ctx, val);
}

extern "C" void DupValue(JSContext *ctx, JSValue val)
{
  JS_DupValue(ctx, val);
}

extern "C" JSValue GetProperty(JSContext *ctx, JSValue this_obj, JSAtom prop){
  return JS_GetProperty(ctx, this_obj, prop);
}

extern "C" const char * ToCString(JSContext *ctx, JSValue val)
{
  return JS_ToCString(ctx, val);
}