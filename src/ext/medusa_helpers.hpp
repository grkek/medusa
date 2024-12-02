#ifndef MEDUSA_HELPERS_HPP
#define MEDUSA_HELPERS_HPP

#include <gc/gc.h> // Boehm GC
#include <string.h>
#include <stdlib.h> // abort()
#include <stdio.h> // fprintf()

// Compiler branching hint
#define likely(x) __builtin_expect(!!(x), 1)

static __attribute__((noreturn)) void fatal_panic(const char *message) {
  fprintf(stderr, "Fatal error in bindings: %s\n", message);
  abort();
}

#ifdef __cplusplus
#include <gc/gc_cpp.h>
#include <string>
#include <type_traits>
#include <utility>
#include <new>

// Break C++'s encapsulation to allow easy wrapping of protected methods.
#define protected public

template<int, typename Callable, typename Ret, typename... Args>
auto fnptr_(Callable&& c, Ret (*)(Args...))
{
    static std::decay_t<Callable> storage = std::forward<Callable>(c);
    static bool used = false;
    if(used)
    {
        using type = decltype(storage);
        storage.~type();
        new (&storage) type(std::forward<Callable>(c));
    }
    used = true;

    return [](Args... args) -> Ret {
        auto& c = *std::launder(&storage);
        return Ret(c(std::forward<Args>(args)...));
    };
}

template<typename Fn, int N = 0, typename Callable>
Fn* fnptr(Callable&& c)
{
    return fnptr_<N>(std::forward<Callable>(c), (Fn*)nullptr);
}

/* Wrapper for a Crystal `Proc`. */
template<typename T, typename ... Args>
struct CrystalProcedure {
  union {
    T (*withSelf)(void *, Args ...);
    T (*withoutSelf)(Args ...);
  };

  void *self;

  CrystalProcedure() : withSelf(nullptr), self(nullptr) { }

  inline bool isValid() const {
    return (withSelf != nullptr);
  }

  /* Fun fact: If the Crystal `Proc` doesn't capture any context, it won't
   * allocate any - But also don't expect any!  We have to accomodate for this
   * by only passing `this->self` if it is non-NULL.
   */

  T operator()(Args ... arguments) const {
    if (this->self) {
      return this->withSelf(this->self, arguments...);
    } else {
      return this->withoutSelf(arguments...);
    }
  }
};

template <typename T>
struct CrystalGCWrapper: public T, public gc_cleanup
{
  using T::T;
};

/// A simple wrapper around a non-pointer type that allows a single
/// dereference operation.
template <typename T>
struct bg_deref {
  T data;

  template<typename... Args>
  bg_deref(Args&&... args) : data(std::forward<Args>(args)...) {}

  T operator*() && { return std::move(data); }
};

#endif // __cplusplus
#endif