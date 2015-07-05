#This class handels the result when running MRI (or others).
class Baza::Driver::Sqlite3::Result < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(driver, statement)
    @statement = statement

    begin
      @statement.execute
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
    return hash = Hash[*@columns.zip(array).flatten] if array
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
end
