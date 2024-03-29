class Baza::Driver::ActiveRecord::Indexes
  def initialize(args)
    @args = args
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].driver.driver_type)).const_get(:Indexes).new(@args)
  end

  def method_missing(...)
    @proxy_to.__send__(...)
  end
end
