# This class handels the result when running MRI (or others).
class Baza::Driver::Sqlite3::Result < Baza::ResultBase
  # Constructor. This should not be called manually.
  def initialize(driver, statement)
    @statement = statement

    begin
      @statement.execute
      @type_translation = driver.db.opts[:type_translation]
      @types = statement.types if @type_translation == true
      @columns = statement.columns.map(&:to_sym)
      read_results
      @index = -1
    ensure
      @statement.close
    end
  end

  # Returns a single result.
  def fetch
    row = @results[@index += 1]
    return unless row

    if @types
      row.map!.with_index { |value, index| translate_type(value, @types[index]) } if @types
    elsif @type_translation == :string
      row.map!(&:to_s)
    end

    Hash[*@columns.zip(row).flatten]
  end

  # Loops over every result yielding them.
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

  def read_results
    @results = []

    loop do
      row = @statement.step
      break if @statement.done?
      @results << row
    end
  end

  def translate_type(value, type)
    return if value.to_s.empty?

    if type == "datetime"
      return nil if value == "NULL"
      return Time.parse(value)
    elsif type == "date"
      return nil if value == "NULL"
      return Date.parse(value)
    else
      value
    end
  end
end
