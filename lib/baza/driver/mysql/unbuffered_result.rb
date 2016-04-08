# This class controls the unbuffered result for the normal MySQL-driver.
class Baza::Driver::Mysql::UnbufferedResult < Baza::ResultBase
  # Constructor. This should not be called manually.
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

  # Returns a single result.
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
        # Reset it to run non-unbuffered again and then return false.
        @conn.query_with_result = true
        return false
      rescue StopIteration
        sleep 0.1
        retry
      end
    end

    if @as_hash
      load_keys unless @keys
      return Hash[*@keys.zip(ret).flatten]
    else
      return ret
    end
  end

  # Loops over every single result yielding it.
  def each
    loop do
      row = fetch

      if row
        yield row
      else
        break
      end
    end
  end

private

  # Lods the keys for the object.
  def load_keys
    @keys = []
    keys = @res.fetch_fields
    keys.each do |key|
      @keys << key.name.to_sym
    end
  end
end
