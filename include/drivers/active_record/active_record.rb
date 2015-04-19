class Baza::Driver::ActiveRecord
  attr_reader :baza, :conn, :sep_table, :sep_col, :sep_val, :symbolize, :conn_type
  attr_accessor :tables, :cols, :indexes

  def self.from_object(args)
    if args[:object].class.name.include?("ActiveRecord::ConnectionAdapters")
      if args[:object].class.name.include?("ConnectionPool")
        object_to_use = args[:object].connection
      else
        object_to_use = args[:object]
      end

      return {
        type: :success,
        args: {
          type: :active_record,
          conn: object_to_use
        }
      }
    end

    return nil
  end

  def initialize(baza)
    @baza = baza
    @conn = @baza.opts[:conn]
    conn_name = @conn.class.name.to_s.downcase

    if conn_name.include?("mysql")
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @conn_type = :mysql
    elsif conn_name.include?("sqlite")
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @conn_type = :sqlite3
    else
      raise "Unknown type: '#{conn_name}'."
    end
  end

  def query(str)
    Baza::Driver::ActiveRecord::Result.new(@conn.execute(str))
  end

  def escape(str)
    @conn.quote_string(str.to_s)
  end

  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(@sep_col)
    return string
  end

  def esc_table(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(@sep_col)
    return string
  end

  def close
    @conn.close
  end

  def transaction
    if @conn_type == :mysql
      query("START TRANSACTION")
    elsif @conn_type == :sqlite3
      query("BEGIN TRANSACTION")
    end

    begin
      yield @baza
      query("COMMIT")
    rescue
      query("ROLLBACK")
      raise
    end
  end
end

class Baza::Driver::ActiveRecord::Result
  def initialize(res)
    @res = res
  end

  def enum
    @enum ||= Enumerator.new do |y|
      @res.each do |result|
        y << result.symbolize_keys
      end
    end
  end

  def fetch
    begin
      return enum.next
    rescue StopIteration
      return false
    end
  end

  def each(&blk)
    enum.each &blk
  end
end

class Baza::Driver::ActiveRecord::Tables
  def initialize(args)
    @args = args

    require_relative "../#{@args[:db].conn.conn_type}/#{@args[:db].conn.conn_type}_tables"
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].conn.conn_type)).const_get(:Tables).new(@args)
  end

  def method_missing(name, *args, &blk)
    @proxy_to.__send__(name, *args, &blk)
  end
end

class Baza::Driver::ActiveRecord::Columns
  def initialize(args)
    @args = args

    require_relative "../#{@args[:db].conn.conn_type}/#{@args[:db].conn.conn_type}_columns"
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].conn.conn_type)).const_get(:Columns).new(@args)
  end

  def method_missing(name, *args, &blk)
    @proxy_to.__send__(name, *args, &blk)
  end
end

class Baza::Driver::ActiveRecord::Indexes
  def initialize(args)
    @args = args

    require_relative "../#{@args[:db].conn.conn_type}/#{@args[:db].conn.conn_type}_indexes"
    @proxy_to = ::Baza::Driver.const_get(StringCases.snake_to_camel(@args[:db].conn.conn_type)).const_get(:Indexes).new(@args)
  end

  def method_missing(name, *args, &blk)
    @proxy_to.__send__(name, *args, &blk)
  end
end
