require "../src/medusa"
require "uuid"

alias QuickJS = Medusa::Binding::QuickJS

engine = Medusa::Engine.new

value = Medusa::ValueWrapper.new(engine.context.to_unsafe, true)
value2 = Medusa::ValueWrapper.new(engine.context.to_unsafe, false)

puts "Is equal? #{value == value2}"

value3 = Medusa::ValueWrapper.new(engine.context.to_unsafe, {"hello" => JSON::Any.new("world")})

puts "What value did we set for hello? #{value3["hello"].as_s}"

pp Medusa::Constants::JS_PROP_C_W_E

value4 = Medusa::ValueWrapper.new(engine.context.to_unsafe, [
  JSON::Any.new("1"),
  JSON::Any.new(2),
  JSON::Any.new(true),
  JSON::Any.new(1.1),
  JSON::Any.new({
    "1" => JSON::Any.new("Hello, World!"),
  }),
]
)

puts "Third entry in the array: #{value4[2].as_bool}"

# Printing the converted type
pp value4.as_a

input = <<-JS
function exampleTest(){
  return {
    "1": "2",
    "3": true,
    "4": null,
    "helloWorld": () => {
      // Functions are currently returned as {} in the Crystal world, might change them to Proc.
      return 1;
    }
  }
}

exampleTest();
JS

pp engine.eval_string(input).as_h

texts = [] of String

texts.push(UUID.random.to_s)

function_pointer = engine.context.new_c_function_pointer(
  ->(context : QuickJS::JSContext, this : QuickJS::JSValue, argc : Int32, argv : QuickJS::JSValue*) {
    # Get the arguments
    # values = [] of Medusa::ValueWrapper
    # slices = Slice.new(argv, argc)

    # slices.each do |slice|
    #   value = Medusa::ValueWrapper.new(engine.context.to_unsafe, slice)

    #   values.push(value)
    # end

    pp texts

    # You have to return JSValue to the Proc
    Medusa::ValueWrapper.new(context, "Return value :)").to_unsafe
  }
)

function = engine.context.new_c_function(function_pointer, "helloWorld", 0)

# Provied a local 'this' by wrapping an empty hash

value5 = engine.call(function, Medusa::ValueWrapper.new(engine.context.to_unsafe, {} of String => JSON::Any))

puts value5.as_s
