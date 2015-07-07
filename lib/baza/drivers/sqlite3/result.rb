#This class handels the result when running MRI (or others).
class Baza::Driver::Sqlite3::Result < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(driver, statement)
    @statement = statement

    begin
      @statement.execute

      if driver.baza.opts[:type_translation]
        @types = statement.types
      elsif driver.baza.opts[:type_translation] === false
        @types = false
      end

      @columns = statement.columns.map { |column| column.to_sym }
      read_results
      @index = -1
    ensure
      @statement.close
    end
  end

  #Returns a single result.
  def fetch
    array = @results[@index += 1]

    if array
      if @types
        array.map!.with_index { |value, index| translate_type(value, @types[index]) } if @types
      elsif @types === false
        array.map! { |value| value.to_s }
      end

      return Hash[*@columns.zip(array).flatten]
    end
  end

  #Loops over every result yielding them.
  def each
    while data = fetch
      yield data
    end
  end

private

  def read_results
    @results = []

    loop do
      array = @statement.step
      break if @statement.done?
      @results << array
    end
  end

  def translate_type(value, type)
    if value
      if type == 'datetime'
        return Time.parse(value)
      elsif type == 'date'
        return Date.parse(value)
      else
        return value
      end
    end
  end
end
