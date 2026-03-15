require "../medusa/binding/quickjs"

module Glue
  alias QuickJS = Medusa::Binding::QuickJS

  # Wraps a Crystal `Proc` into a `QuickJS::CrystalProcedure` for C++ interop.
  def self.wrap_procedure(procedure : Proc(Medusa::Binding::QuickJS::JSContext, Medusa::Binding::QuickJS::JSValue, Int32, Pointer(Medusa::Binding::QuickJS::JSValue), Medusa::Binding::QuickJS::JSValue))
    QuickJS::CrystalProcedure.new(
      pointer: procedure.pointer,
      context: procedure.closure_data,
    )
  end

  def self.wrap_procedure(nothing : Nil)
    QuickJS::CrystalProcedure.new(
      pointer: Pointer(Void).null,
      context: Pointer(Void).null,
    )
  end

  macro wrap_container(wrapper, list)
    %instance = {{ list }}
    {% unless list.resolve <= Enumerable %}
      {% raise "Expected Enumerable type for list, got #{list.resolve}" %}
    {% end %}
    if %instance.is_a?({{ wrapper }})
      %instance
    else
      {{wrapper}}.new.concat(%instance)
    end
  end

  module SequentialContainer(T)
    include Indexable(T)

    abstract def push(value : T)

    def <<(value : T) : self
      push(value)
      self
    end

    def concat(values : Enumerable(T)) : self
      values.each { |v| push(v) }
      self
    end

    def to_s(io)
      to_a.to_s(io)
    end

    def inspect(io)
      io << "<Wrapped "
      to_a.inspect(io)
      io << ">"
    end
  end
end
