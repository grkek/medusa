require "uuid"
require "./ext/**"

require "./medusa/binding/quickjs"
require "./medusa/api/**"
require "./medusa/**"

module Medusa
end

alias QuickJS = Medusa::Binding::QuickJS

class Engine
  INSTANCE = new

  def self.instance
    INSTANCE
  end

  property id : String = UUID.random.to_s

  def initialize
    @rt = Medusa::Runtime.new
    @ctx = Medusa::Context.new(@rt.to_unsafe)

    function_pointer = @ctx.new_c_function_pointer(->(ctx : QuickJS::JSContext, this_value : QuickJS::JSValue, argc : Int32, argv : QuickJS::JSValue*) {
      slices = Slice.new(argv, argc)

      slices.each do |slice|
        value = Medusa::Value.new(@ctx.to_unsafe, slice)

        if value.to_unsafe.tag == QuickJS::Tag::STRING
          return value.to_unsafe
        end
      end

      raise Exception.new("You should not get here")
    })

    function = @ctx.new_c_function(function_pointer, "helloWorld", 0)

    global_object = @ctx.get_global_object

    @ctx.set_property_str(global_object.to_unsafe, "helloWorld", function.to_unsafe)
  end

  def eval_string(input : String) : Medusa::Value
    @ctx.eval_string(input)
  end
end


spawn do
  pp Engine.instance.eval_string("helloWorld(1, 2, 3, 4, \"Hello, World!\")")
end

sleep
