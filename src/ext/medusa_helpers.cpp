#include "medusa_helpers.hpp"
#include "quickjs/quickjs.h"
#include "quickjs/quickjs-libc.h"

extern "C" JSContext *JS_NewBuiltInContext(JSRuntime *rt)
{
  JSContext *ctx = JS_NewContext(rt);

  js_std_init_handlers(rt);

  js_init_module_std(ctx, "std");
  js_init_module_os(ctx, "os");

  const char *input = "import * as std from 'std';\nimport * as os from 'os';\nglobalThis.std = std;\nglobalThis.os = os;";

  JS_Eval(ctx, input, strlen(input), "<input>", JS_EVAL_TYPE_MODULE);

  return ctx;
}

extern "C" JSCFunction *JS_NewCFunctionPointer(CrystalProcedure<JSValue, JSContext *, JSValue, int, JSValue *> crystalProcedure)
{
  return fnptr<JSCFunction>([crystalProcedure](JSContext *ctx, JSValue thisValue, int argc, JSValue *argv)
                            { return crystalProcedure(ctx, thisValue, argc, argv); });
}

extern "C" JSValue JS_NewCFunctionDefault(JSContext *ctx, JSCFunction *func, const char *name, int length)
{
  return JS_NewCFunction(ctx, func, name, length);
}

extern "C" const char *JS_ValueToCString(JSContext *ctx, JSValue val)
{
  return JS_ToCString(ctx, val);
}

extern "C" void JS_FreeValueDefault(JSContext *ctx, JSValue v)
{
  return JS_FreeValue(ctx, v);
}