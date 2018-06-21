# This class controls the results for the normal MySQL-driver.
class Baza::Driver::Mysql::Result < Baza::ResultBase
  # Constructor. This should not be called manually.
  def initialize(driver, result)
    @driver = driver
    @result = result
    @mutex = Mutex.new
    @type_translation = driver.db.opts[:type_translation]

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
    elsif @type_translation == :string
      fetched.collect!(&:to_s)
    end

    Hash[*@keys.zip(fetched).flatten]
  end

  # Loops over every result yielding it.
  def each
    loop do
      data = fetch

      if data
        yield data
      else
        break
      end
    end
  end

private

  def translate_value_to_type(value, type_no)
    return if value == nil

    case type_no
    when ::Mysql::Field::TYPE_DECIMAL, ::Mysql::Field::TYPE_TINY, ::Mysql::Field::TYPE_LONG, ::Mysql::Field::TYPE_YEAR
      value.to_i
    when ::Mysql::Field::TYPE_DECIMAL, ::Mysql::Field::TYPE_FLOAT, ::Mysql::Field::TYPE_DOUBLE
      value.to_f
    when ::Mysql::Field::TYPE_DATETIME
      Time.parse(value)
    when ::Mysql::Field::TYPE_DATE
      Date.parse(value)
    else
      value.to_s
    end
  end
end
