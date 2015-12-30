# This class controls the results for the normal MySQL-driver.
class Baza::Driver::Mysql::Result < Baza::ResultBase
  INT_TYPES = {
    ::Mysql::Field::TYPE_DECIMAL => true,
    ::Mysql::Field::TYPE_TINY => true,
    ::Mysql::Field::TYPE_LONG => true,
    ::Mysql::Field::TYPE_YEAR => true
  }
  FLOAT_TYPES = {
    ::Mysql::Field::TYPE_DECIMAL => true,
    ::Mysql::Field::TYPE_FLOAT => true,
    ::Mysql::Field::TYPE_DOUBLE => true
  }
  TIME_TYPES = {
    ::Mysql::Field::TYPE_DATETIME => true
  }
  DATE_TYPES = {
    ::Mysql::Field::TYPE_DATE => true
  }

  # Constructor. This should not be called manually.
  def initialize(driver, result)
    @driver = driver
    @result = result
    @mutex = Mutex.new
    @type_translation = driver.baza.opts[:type_translation]

    return unless @result

    @keys = []
    @types = [] if @type_translation

    @result.fetch_fields.each do |key|
      @keys << key.name.to_sym
      @types << key.type if @type_translation
    end
  end

  # Returns a single result as a hash with symbols as keys.
  def fetch
    fetched = nil
    @mutex.synchronize do
      fetched = @result.fetch_row
    end

    return false unless fetched

    if @type_translation == true
      fetched.collect!.with_index do |value, count|
        translate_value_to_type(value, @types[count])
      end
    end

    Hash[*@keys.zip(fetched).flatten]
  end

  # Loops over every result yielding it.
  def each
    while data = fetch
      yield data
    end
  end

private

  def translate_value_to_type(value, type_no)
    return if value == nil

    if INT_TYPES[type_no]
      return value.to_i
    elsif FLOAT_TYPES[type_no]
      return value.to_f
    elsif TIME_TYPES[type_no]
      return Time.parse(value)
    elsif DATE_TYPES[type_no]
      return Date.parse(value)
    else
      return value.to_s
    end
  end
end
