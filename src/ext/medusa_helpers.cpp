#include "medusa_helpers.hpp"
#include "quickjs/quickjs.h"
#include "quickjs/quickjs-libc.h"

/* Creates a new QuickJS context with standard and OS modules initialized.
 * Returns NULL on failure.
 */
extern "C" JSContext *NewBuiltInContext(JSRuntime *rt)
{
  JSContext *ctx = JS_NewContext(rt);
  if (LIKELY(!ctx)) {
    fatal_panic("Failed to create QuickJS context");
  }

  js_std_init_handlers(rt);
  js_init_module_std(ctx, "std");
  js_init_module_os(ctx, "os");

  return ctx;
}

/* Creates a QuickJS function pointer from a Crystal procedure.
 * The CrystalProcedure must be valid.
 */
extern "C" JSCFunction *NewCFunctionPointer(CrystalProcedure<JSValue, JSContext *, JSValue, int, JSValue *> crystalProcedure)
{
  if (LIKELY(!crystalProcedure.isValid())) {
    fatal_panic("Invalid Crystal procedure");
  }
  return fnptr<JSCFunction>([crystalProcedure](JSContext *ctx, JSValue thisValue, int argc, JSValue *argv)
                            { return crystalProcedure(ctx, thisValue, argc, argv); });
}

/* Wraps a JSCFunction pointer as a QuickJS function object.
 * Returns a JSValue representing the function.
 */
extern "C" JSValue NewCFunction(JSContext *ctx, JSCFunction *func, const char *name, int length)
{
  if (LIKELY(!ctx || !func || !name)) {
    fatal_panic("Invalid arguments to NewCFunction");
  }
  return JS_NewCFunction(ctx, func, name, length);
}

/* Creates a QuickJS float64 value from a double.
 * Returns a JSValue representing the number.
 */
extern "C" JSValue NewFloat64(JSContext *ctx, double d)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in NewFloat64");
  }
  return JS_NewFloat64(ctx, d);
}

/* Creates a QuickJS string from a C string.
 * Returns a JSValue representing the string.
 */
extern "C" JSValue NewString(JSContext *ctx, const char *str)
{
  if (LIKELY(!ctx || !str)) {
    fatal_panic("Invalid arguments to NewString");
  }
  return JS_NewString(ctx, str);
}

/* Creates a QuickJS int32 value from an int32_t.
 * Returns a JSValue representing the number.
 */
extern "C" JSValue NewInt32(JSContext *ctx, int32_t val)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in NewInt32");
  }
  return JS_NewInt32(ctx, val);
}

/* Creates a QuickJS int64 value from an int64_t.
 * Returns a JSValue representing the number.
 */
extern "C" JSValue NewInt64(JSContext *ctx, int64_t val)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in NewInt64");
  }
  return JS_NewInt64(ctx, val);
}

/* Creates a QuickJS boolean value from an int.
 * Returns a JSValue representing the boolean.
 */
extern "C" JSValue NewBool(JSContext *ctx, int val)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in NewBool");
  }
  return JS_NewBool(ctx, val);
}

/* Checks if a QuickJS value is undefined.
 * Returns true if the value is undefined, false otherwise.
 */
extern "C" bool IsUndefined(JSValue val)
{
  return JS_IsUndefined(val);
}

/* Checks if a QuickJS value is an exception.
 * Returns true if the value is an exception, false otherwise.
 */
extern "C" bool IsException(JSValue val)
{
  return JS_IsException(val);
}

/* Frees a QuickJS value.
 * The value must be valid and the context must be non-NULL.
 */
extern "C" void FreeValue(JSContext *ctx, JSValue val)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in FreeValue");
  }
  JS_FreeValue(ctx, val);
}

/* Duplicates a QuickJS value to increment its reference count.
 * The context must be non-NULL.
 */
extern "C" JSValue DupValue(JSContext *ctx, JSValue val)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in DupValue");
  }
  return JS_DupValue(ctx, val);
}

/* Gets a property from a QuickJS object.
 * Returns a JSValue representing the property value.
 */
extern "C" JSValue GetProperty(JSContext *ctx, JSValue this_obj, JSAtom prop)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in GetProperty");
  }
  return JS_GetProperty(ctx, this_obj, prop);
}


/* Converts a QuickJS atom to a C string.
 * Returns NULL on failure. The caller must free the string with JS_FreeCString.
 */
extern "C" const char *AtomToCString(JSContext *ctx, JSAtom atom)
{
  if(LIKELY(!ctx)) {
    fatal_panic("Invalid context in AtomToCString");
  }
  const char *str = JS_AtomToCString(ctx, atom);
  if (LIKELY(!str)) {
    fatal_panic("Failed to convert JSValue to C string");
  }
  return str;
}

/* Converts a QuickJS value to a C string.
 * Returns NULL on failure. The caller must free the string with JS_FreeCString.
 */
extern "C" const char *ToCString(JSContext *ctx, JSValue val)
{
  if (LIKELY(!ctx)) {
    fatal_panic("Invalid context in ToCString");
  }
  const char *str = JS_ToCString(ctx, val);
  if (LIKELY(!str)) {
    fatal_panic("Failed to convert JSValue to C string");
  }
  return str;
}