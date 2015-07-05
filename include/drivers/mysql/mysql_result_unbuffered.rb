#This class controls the unbuffered result for the normal MySQL-driver.
class Baza::Driver::Mysql::ResultUnbuffered < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(conn, opts, result)
    @conn = conn
    @result = result

    if !opts.key?(:result) || opts[:result] == "hash"
      @as_hash = true
    elsif opts[:result] == "array"
      @as_hash = false
    else
      raise "Unknown type of result: '#{opts[:result]}'."
    end
  end

  #Returns a single result.
  def fetch
    if @enum
      begin
        ret = @enum.next
      rescue StopIteration
        @enum = nil
        @res = nil
      end
    end

    if !ret && !@res && !@enum
      begin
        @res = @conn.use_result
        @enum = @res.to_enum
        ret = @enum.next
      rescue Mysql::Error
        #Reset it to run non-unbuffered again and then return false.
        @conn.query_with_result = true
        return false
      rescue StopIteration
        sleep 0.1
        retry
      end
    end

    if !@as_hash
      return ret
    else
      self.load_keys if !@keys

      ret_h = {}
      @keys.each_index do |key_no|
        ret_h[@keys[key_no]] = ret[key_no]
      end

      return ret_h
    end
  end

  #Loops over every single result yielding it.
  def each
    while data = self.fetch
      yield(data)
    end
  end

private

  #Lods the keys for the object.
  def load_keys
    @keys = []
    keys = @res.fetch_fields
    keys.each do |key|
      @keys << key.name.to_sym
    end
  end
end
