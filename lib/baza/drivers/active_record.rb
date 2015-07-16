class Baza::Driver::ActiveRecord
  path = "#{File.dirname(__FILE__)}/active_record"

  autoload :Tables, "#{path}/tables"
  autoload :Columns, "#{path}/columns"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"

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

    raise 'No conn given' unless @conn

    conn_name = @conn.class.name.to_s.downcase

    if conn_name.include?("mysql2")
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @conn_type = :mysql2
      @result_constant = Baza::Driver::Mysql2::Result
    elsif conn_name.include?("mysql")
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @conn_type = :mysql
      @result_constant = Baza::Driver::Mysql::Result unless RUBY_PLATFORM == 'java'
    elsif conn_name.include?("sqlite")
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @conn_type = :sqlite3
    else
      raise "Unknown type: '#{conn_name}'."
    end

    @result_constant ||= Baza::Driver::ActiveRecord::Result
  end

  def query(sql)
    @result_constant.new(self, @conn.execute(sql))
  end

  alias query_ubuf query

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
    if @conn_type == :mysql || @conn_type == :mysql2
      query("START TRANSACTION")
    elsif @conn_type == :sqlite3
      query("BEGIN TRANSACTION")
    else
      raise "Don't know how to start transaction"
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
