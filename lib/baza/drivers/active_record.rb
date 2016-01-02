class Baza::Driver::ActiveRecord < Baza::BaseSqlDriver
  path = "#{File.dirname(__FILE__)}/active_record"

  autoload :Tables, "#{path}/tables"
  autoload :Columns, "#{path}/columns"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"

  attr_reader :db, :conn, :sep_table, :sep_col, :sep_val, :symbolize, :driver_type
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

    nil
  end

  def initialize(db)
    @db = db
    @conn = @db.opts.fetch(:conn)

    raise "No conn given" unless @conn

    conn_name = @conn.class.name.to_s.downcase

    if conn_name.include?("mysql2")
      require_relative "mysql2"
      require_relative "mysql2/result"

      @sep_database = "`"
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @sep_index = "`"
      @driver_type = :mysql2
      @result_constant = Baza::Driver::Mysql2::Result
    elsif conn_name.include?("mysql")
      unless RUBY_PLATFORM == "java"
        require_relative "mysql"
        require_relative "mysql/result"
        @result_constant = Baza::Driver::Mysql::Result
      end

      @sep_database = "`"
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @sep_index = "`"
      @driver_type = :mysql
    elsif conn_name.include?("sqlite")
      @sep_database = "`"
      @sep_table = "`"
      @sep_col = "`"
      @sep_val = "'"
      @sep_index = "`"
      @driver_type = :sqlite3
    elsif conn_name.include?("postgresqladapter")
      @sep_database = '"'
      @sep_table = '"'
      @sep_col = '"'
      @sep_index = '"'
      @sep_val = "'"
      @driver_type = :pg
      @result_constant = Baza::Driver::Pg::Result
    else
      raise "Unknown type: '#{conn_name}'"
    end

    @result_constant ||= Baza::Driver::ActiveRecord::Result

    if conn_name.include?("mysql")
      @db.opts[:db] ||= query("SELECT DATABASE()").fetch.fetch(:"DATABASE()")
    elsif @driver_type == :pg
      @db.opts[:db] ||= query("SELECT current_database()").fetch.values.first
    end
  end

  def query(sql)
    @result_constant.new(self, @conn.execute(sql))
  end

  alias_method :query_ubuf, :query

  def escape(str)
    @conn.quote_string(str.to_s)
  end

  def escape_column(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(@sep_col)
    string
  end

  def escape_table(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(@sep_col)
    string
  end

  def close
    @conn.close
  end

  def transaction
    if @driver_type == :mysql || @driver_type == :mysql2 || @driver_type == :pg
      query("START TRANSACTION")
    elsif @driver_type == :sqlite3
      query("BEGIN TRANSACTION")
    else
      raise "Don't know how to start transaction"
    end

    begin
      yield @db
      query("COMMIT")
    rescue
      query("ROLLBACK")
      raise
    end
  end

  def supports_multiple_databases?
    conn_name.include?("mysql") || @driver_type == :pg
  end
end
