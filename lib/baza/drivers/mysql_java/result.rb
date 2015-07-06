#This class controls the result for the Java-MySQL-driver.
class Baza::Driver::MysqlJava::Result < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(knjdb, opts, result)
    @baza_db = knjdb
    @result = result
  end

  def fetch
    return false unless @result
    read_meta unless @keys

    unless @result.next
      @result = nil
      return false
    end

    ret = {}
    @count.times do |count|
      ret[@keys[count]] = @result.object(count + 1)
    end

    return ret
  end

  def each
    while data = fetch
      yield data
    end
  end

private

  #Reads meta-data about the query like keys and count.
  def read_meta
    @result.before_first
    meta = @result.meta_data
    @count = meta.column_count

    @keys = []
    1.upto(@count) do |count|
      @keys << meta.column_label(count).to_sym
    end
  end
end
