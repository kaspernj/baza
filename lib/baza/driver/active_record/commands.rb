class Baza::Driver::ActiveRecord::Commands
  def initialize(args)
    @db = args.fetch(:db)
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@db.driver.driver_type)).const_get(:Commands).new(args)
  end

  def method_missing(name, *args, &blk)
    @proxy_to.__send__(name, *args, &blk)
  end
end
