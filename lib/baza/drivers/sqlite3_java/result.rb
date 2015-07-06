class Baza::Driver::Sqlite3Java::Result < Baza::ResultBase
  def initialize(driver, result_set)
    @result_set = result_set
    @index = -1
    @rows = []

    if @result_set
      read_columns
      read_results
    end
  end

  def fetch
    return @rows[@index += 1]
  end

  def each
    while data = fetch
      yield data
    end
  end

private

  def read_columns
    metadata = @result_set.meta_data
    @columns_count = metadata.column_count
    @columns = []

    1.upto(@columns_count) do |count|
      @columns << metadata.column_name(count).to_sym
    end
  end

  def read_results
    while @result_set.next
      hash = {}
      @columns_count.times do |count|
        hash[@columns[count]] = @result_set.string(count + 1)
      end

      @rows << hash
    end
  end
end
