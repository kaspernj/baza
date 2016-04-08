class Baza::Driver::Sqlite3Java::UnbufferedResult < Baza::ResultBase
  def initialize(_driver, result_set)
    @result_set = result_set
    return unless @result_set

    metadata = @result_set.meta_data
    @columns_count = metadata.column_count

    @columns = []
    1.upto(@columns_count) do |count|
      @columns << metadata.column_name(count).to_sym
    end
  end

  def fetch
    result = @result_set.next if @result_set
    return nil unless result

    hash = {}
    @columns_count.times do |count|
      hash[@columns[count]] = @result_set.string(count + 1)
    end

    hash
  end

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
end
