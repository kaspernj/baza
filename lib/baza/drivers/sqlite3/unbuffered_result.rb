class Baza::Driver::Sqlite3::UnbufferedResult
  def initialize(_driver, statement)
    @statement = statement
    @statement.execute
    @columns = statement.columns.map(&:to_sym)
  end

  def fetch
    return nil if @closed

    array = @statement.step

    if @statement.done?
      close
      return nil
    end

    return Hash[*@columns.zip(array).flatten] if array
  end

  def each
    while data = fetch
      yield data
    end
  end

private

  def close
    @statement.close
    @closed = true
  end
end
