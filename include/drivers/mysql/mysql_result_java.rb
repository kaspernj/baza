#This class controls the result for the Java-MySQL-driver.
class Baza::Driver::Mysql::ResultJava
  #Constructor. This should not be called manually.
  def initialize(knjdb, opts, result)
    @baza_db = knjdb
    @result = result

    if !opts.key?(:result) || opts[:result] == "hash"
      @as_hash = true
    elsif opts[:result] == "array"
      @as_hash = false
    else
      raise "Unknown type of result: '#{opts[:result]}'."
    end
  end

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

  def fetch
    return false unless @result
    self.read_meta unless @keys
    status = @result.next

    unless status
      @result = nil
      @keys = nil
      @count = nil
      return false
    end

    if @as_hash
      ret = {}
      1.upto(@count) do |count|
        ret[@keys[count - 1]] = @result.object(count)
      end
    else
      ret = []
      1.upto(@count) do |count|
        ret << @result.object(count)
      end
    end

    return ret
  end

  def each
    while data = self.fetch
      yield(data)
    end
  end
end
