require "../medusa/binding/quickjs"

module Glue
  alias QuickJS = Medusa::Binding::QuickJS

  # Wraps a Crystal `Proc` into a `QuickJS::CrystalProcedure` for C++ interop.
  # The Proc must match the QuickJS function signature.
  def self.wrap_procedure(procedure : Proc(Medusa::Binding::QuickJS::JSContext, Medusa::Binding::QuickJS::JSValue, Int32, Pointer(Medusa::Binding::QuickJS::JSValue), Medusa::Binding::QuickJS::JSValue))
    QuickJS::CrystalProcedure.new(
      pointer: procedure.pointer,
      context: procedure.closure_data,
    )
  end

  # Returns a null `QuickJS::CrystalProcedure` for cases where no procedure is provided.
  def self.wrap_procedure(nothing : Nil)
    QuickJS::CrystalProcedure.new(
      pointer: Pointer(Void).null,
      context: Pointer(Void).null,
    )
  end

  # Wraps a list into a container wrapper if it's not already one.
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

  # Wrapper for an instantiated, sequential container type for data transmission.
  module SequentialContainer(T)
    include Indexable(T)

    # Adds an element at the end. Must be implemented by the wrapper.
    abstract def push(value : T)

    # Adds an element at the end of the container.
    def <<(value : T) : self
      push(value)
      self
    end

    # Adds all elements at the end of the container, retaining their order.
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
