class Baza::Driver::ActiveRecord::Users
  def initialize(args)
    @args = args

    require "#{File.dirname(__FILE__)}/../#{@args.fetch(:db).driver.driver_type}"
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args.fetch(:db).driver.driver_type)).const_get(:Users).new(@args)
  end

  def method_missing(...)
    @proxy_to.__send__(...)
  end
end
