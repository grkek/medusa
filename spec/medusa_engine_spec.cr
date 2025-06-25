require "./spec_helper"

describe Medusa::Engine do
  it "sums up two numbers together" do
    engine = Medusa::Engine.new
    result = engine.eval_string("function add(a, b) { return a + b; } add(5, 3);")

    result.as_i.should eq 8
  end

  it "formats a string" do
    engine = Medusa::Engine.new
    result = engine.eval_string("function format(a, b) { return `${a}, ${b}`; } format('Hello', 'World!');")

    result.as_s.should eq "Hello, World!"
  end

  it "executes single and multi thread contexts" do
    engine = Medusa::Engine.new

    result = engine.eval_string("function add(a, b) { return a + b; } add(5, 3);")
    result.as_i.should eq 8

    # Test function call (multithreaded)
    function = engine.eval_string("function multiply(x, y) { return x * y; } multiply;")
    this = engine.eval_string("this")
    args = [
      Medusa::ValueWrapper.new(engine.context.to_unsafe, 4),
      Medusa::ValueWrapper.new(engine.context.to_unsafe, 5),
    ]
    result = engine.call(function, this, args, same_thread: false)
    result.as_i.should eq 20
  end

  it "creates a function and executes it" do
    engine = Medusa::Engine.new

    function_pointer = engine.context.new_c_function_pointer(
      ->(context : Medusa::Binding::QuickJS::JSContext, this : Medusa::Binding::QuickJS::JSValue, argc : Int32, argv : Medusa::Binding::QuickJS::JSValue*) {
        # Get the arguments
        values = [] of Medusa::ValueWrapper
        slices = Slice.new(argv, argc)

        slices.each do |slice|
          value = Medusa::ValueWrapper.new(engine.context.to_unsafe, slice)

          values.push(value)
        end

        value = Medusa::ValueWrapper.new(engine.context.to_unsafe, "Hello, World!")

        # You have to return JSValue to the Proc
        value.duplicate
      }
    )

    function = engine.context.new_c_function(function_pointer, "helloWorld", 0)
    this = engine.eval_string("this")
    result = engine.call(function, this)

    result.as_s.should eq "Hello, World!"
  end

  it "fetches this as an object and assigns a function to it, then calls it" do
    engine = Medusa::Engine.new

    function_pointer = engine.context.new_c_function_pointer(
      ->(context : Medusa::Binding::QuickJS::JSContext, this : Medusa::Binding::QuickJS::JSValue, argc : Int32, argv : Medusa::Binding::QuickJS::JSValue*) {
        # Get the arguments
        values = [] of Medusa::ValueWrapper
        slices = Slice.new(argv, argc)

        slices.each do |slice|
          value = Medusa::ValueWrapper.new(engine.context.to_unsafe, slice)

          values.push(value)
        end

        value = Medusa::ValueWrapper.new(engine.context.to_unsafe, "Hello, World!")

        # You have to return JSValue to the Proc
        value.duplicate
      }
    )

    this = engine.eval_string("this")
    function = engine.context.new_c_function(function_pointer, "helloWorld", 0)
    this["testFunction"] = function

    result = engine.eval_string("testFunction();")
    result.as_s.should eq "Hello, World!"
  end

  it "fetches this as an object and assigns a new object to it, then retrieves its content" do
    engine = Medusa::Engine.new

    this = engine.eval_string("this")

    this["exampleObject"] = Medusa::ValueWrapper.new(engine.context.to_unsafe, {"hello" => JSON::Any.new("example")})
    result = engine.eval_string("this.exampleObject.hello")
    result.as_s.should eq "example"
  end

  it "creates and uses a class" do
    engine = Medusa::Engine.new

    result = engine.eval_string("class Car { constructor() { this.brand = 'Ford'; } }; let car = new Car(); car.brand;")
    result.as_s.should eq "Ford"
  end

  it "tests closures and channels" do
    engine = Medusa::Engine.new

    channel = Channel(String).new

    function_pointer = engine.context.new_c_function_pointer(
      ->(context : Medusa::Binding::QuickJS::JSContext, this : Medusa::Binding::QuickJS::JSValue, argc : Int32, argv : Medusa::Binding::QuickJS::JSValue*) {
        result = Medusa::ValueWrapper.new(engine.context.to_unsafe, "Hello, World!")

        channel.send(result.as_s)

        result.duplicate
      }
    )

    function = engine.context.new_c_function(function_pointer, String.new, 0)
    this = engine.eval_string("this")

    this["updateComponent"] = function

    spawn do
      if value = channel.receive?
        value.should eq "Hello, World!"
      end
    end

    engine.eval_string("updateComponent()")
  end
end
