require "../src/medusa"
require "uuid"

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
