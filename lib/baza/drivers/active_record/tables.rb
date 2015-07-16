class Baza::Driver::ActiveRecord::Tables
  def initialize(args)
    @args = args

    require "#{File.dirname(__FILE__)}/../#{@args[:db].conn.conn_type}"
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].conn.conn_type)).const_get(:Tables).new(@args)
  end

  def method_missing(name, *args, &blk)
    @proxy_to.__send__(name, *args, &blk)
  end
end
