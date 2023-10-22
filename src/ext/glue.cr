require "../medusa/binding/quickjs"

module Glue
  alias QuickJS = Medusa::Binding::QuickJS

  # Wraps `Proc` to a `Binding::CrystalProcedure`, which can then passed on to C++.
  def self.wrap_procedure(procedure : Proc)
    QuickJS::CrystalProcedure.new(
      pointer: procedure.pointer,
      context: procedure.closure_data,
    )
  end

  # Wraps `Proc` to a `Binding::CrystalProcedure`, which can then passed on to C++.
  # `Nil` version, returns a null-proc.
  def self.wrap_procedure(nothing : Nil)
    QuickJS::CrystalProcedure.new(
      pointer: Pointer(Void).null,
      context: Pointer(Void).null,
    )
  end

  # Wraps a *list* into a container *wrapper*, if it's not already one.
  macro wrap_container(wrapper, list)
    %instance = {{ list }}
    if %instance.is_a?({{ wrapper }})
      %instance
    else
      {{wrapper}}.new.concat(%instance)
    end
  end

  # Wrapper for an instantiated, sequential container type.
  #
  # This offers (almost) all read-only methods known from `Array`.
  # Additionally, there's `#<<`.  Other than that, the container type is not
  # meant to be used for storage, but for data transmission between the C++
  # and the Crystal world.  Don't let that discourage you though.
  module SequentialContainer(T)
    include Indexable(T)

    # `#unsafe_fetch` and `#size` will be implemented by the wrapper class.

    # Adds an element at the end.  Implemented by the wrapper.
    abstract def push(value : T)

    # Adds *element* at the end of the container.
    def <<(value : T) : self
      push(value)
      self
    end

    # Adds all *elements* at the end of the container, retaining their order.
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
