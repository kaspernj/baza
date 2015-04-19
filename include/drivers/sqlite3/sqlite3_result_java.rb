#This class handels results when running in JRuby.
class Baza::Driver::Sqlite3::ResultJava
  def initialize(driver, rs)
    @index = 0
    retkeys = driver.baza.opts[:return_keys]

    if rs
      metadata = rs.getMetaData
      columns_count = metadata.getColumnCount

      @rows = []
      while rs.next
        row_data = {}
        for i in (1..columns_count)
          col_name = metadata.getColumnName(i).to_sym
          row_data[col_name] = rs.getString(i)
        end

        @rows << row_data
      end
    end
  end

  #Returns a single result.
  def fetch
    return false unless @rows
    ret = @rows[@index]
    return false unless ret
    @index += 1
    return ret
  end

  #Loops over every result and yields them.
  def each
    while data = fetch
      yield data
    end
  end
end
