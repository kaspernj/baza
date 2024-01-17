class Baza::Driver::ActiveRecord::ForeignKeys
  def initialize(db:)
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(db.driver.driver_type)).const_get(:ForeignKeys).new(db: db)
  end

  def method_missing(...)
    @proxy_to.__send__(...)
  end

  def respond_to_missing?(method_name)
    @proxy.respond_to?(method_name) || super
  end
end
