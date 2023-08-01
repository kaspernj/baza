class Baza::Driver::ActiveRecord::Databases
  def initialize(args)
    @args = args
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].driver.driver_type)).const_get(:Databases).new(@args)
  end

  def method_missing(...)
    @proxy_to.__send__(...)
  end
end
