class Baza::Driver::ActiveRecord::Columns
  def initialize(args)
    @args = args
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].driver.driver_type)).const_get(:Columns).new(@args)
  end

  def method_missing(name, *args, &blk)
    @proxy_to.__send__(name, *args, &blk)
  end
end
