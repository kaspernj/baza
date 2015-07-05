#This class handels SQLite3-specific behaviour.
class Baza::Driver::Sqlite3
  path = File.dirname(__FILE__)

  autoload :Table, "#{path}/sqlite3_table"
  autoload :Tables, "#{path}/sqlite3_tables"
  autoload :Column, "#{path}/sqlite3_column"
  autoload :Columns, "#{path}/sqlite3_columns"
  autoload :Index, "#{path}/sqlite3_index"
  autoload :Indexes, "#{path}/sqlite3_indexes"
  autoload :Result, "#{path}/sqlite3_result"
  autoload :ResultJava, "#{path}/sqlite3_result_java"
  autoload :Sqlspecs, "#{path}/sqlite3_sqlspecs"
  autoload :UnbufferedResult, "#{path}/sqlite3_unbuffered_result"
  autoload :UnbufferedResultJava, "#{path}/sqlite3_unbuffered_result_java"

  attr_reader :baza, :conn, :sep_table, :sep_col, :sep_val, :symbolize
  attr_accessor :tables, :cols, :indexes

  #Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "SQLite3::Database"
      return {
        type: :success,
        args: {
          type: :sqlite3,
          conn: args[:object]
        }
      }
    elsif args[:object].class.name == "Java::OrgSqlite::SQLiteConnection"
      return {
        type: :success,
        args: {
          type: :sqlite3,
          conn: args[:object]
        }
      }
    end

    return nil
  end

  #Constructor. This should not be called manually.
  def initialize(baza_db)
    @sep_table = "`"
    @sep_col = "`"
    @sep_val = "'"

    @baza = baza_db
    @path = @baza.opts[:path] if @baza.opts[:path]
    @baza.opts[:subtype] ||= :java if RUBY_ENGINE == "jruby"
    @subtype = @baza.opts[:subtype]

    if @baza.opts[:conn]
      @conn = @baza.opts[:conn]
      @stat = @conn.createStatement if @subtype == :java
    else
      raise "No path was given." unless @path

      if @subtype == :java
        if @baza.opts[:sqlite_driver]
          require @baza.opts[:sqlite_driver]
        else
          require "jdbc/sqlite3"
          ::Jdbc::SQLite3.load_driver
        end

        require "java"
        import "org.sqlite.JDBC"
        @conn = java.sql.DriverManager::getConnection("jdbc:sqlite:#{@baza.opts[:path]}")
        @stat = @conn.createStatement
      elsif @subtype == :rhodes
        @conn = ::SQLite3::Database.new(@path, @path)
      else
        @conn = ::SQLite3::Database.open(@path)
      end
    end
  end

  #Executes a query against the driver.
  def query(sql)
    if @subtype == :rhodes
      return Baza::Driver::Sqlite3::Result.new(self, @conn.execute(sql, sql))
    elsif @subtype == :java
      begin
        return Baza::Driver::Sqlite3::ResultJava.new(self, @stat.executeQuery(sql))
      rescue java.sql.SQLException => e
        if e.message.to_s.index("query does not return ResultSet") != nil
          return Baza::Driver::Sqlite3::ResultJava.new(self, nil)
        else
          raise e
        end
      end
    else
      return Baza::Driver::Sqlite3::Result.new(self, @conn.prepare(sql))
    end
  end

  def query_ubuf(sql)
    if @subtype == :java
      begin
        return Baza::Driver::Sqlite3::UnbufferedResultJava.new(self, @stat.executeQuery(sql))
      rescue java.sql.SQLException => e
        if e.message.to_s.index("query does not return ResultSet") != nil
          return Baza::Driver::Sqlite3::UnbufferedResultJava.new(self, nil)
        else
          raise e
        end
      end
    else
      return Baza::Driver::Sqlite3::UnbufferedResult.new(self, @conn.prepare(sql))
    end
  end

  #Escapes a string to be safe to used in a query.
  def escape(string)
    #This code is taken directly from the documentation so we dont have to rely on the SQLite3::Database class. This way it can also be used with JRuby and IronRuby...
    #http://sqlite-ruby.rubyforge.org/classes/SQLite/Database.html
    return string.to_s.gsub(/'/, "''")
  end

  #Escapes a string to be used as a column.
  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.index(@sep_col) != nil
    return string
  end

  alias :esc_table :esc_col
  alias :esc :escape

  #Returns the last inserted ID.
  def last_id
    return @conn.last_insert_row_id if @conn.respond_to?(:last_insert_row_id)
    return query("SELECT last_insert_rowid() AS id").fetch[:id].to_i
  end

  #Closes the connection to the database.
  def close
    @conn.close
  end

  #Starts a transaction, yields the database and commits.
  def transaction
    if @subtype == :java
      query("BEGIN TRANSACTION")

      begin
        yield(@baza)
        query("COMMIT")
      rescue => e
        query("ROLLBACK")
      end
    else
      @conn.transaction do
        yield @baza
      end
    end
  end

  def insert_multi(tablename, arr_hashes, args = nil)
    sql = [] if args && args[:return_sql]

    @baza.transaction do
      arr_hashes.each do |hash|
        res = @baza.insert(tablename, hash, args)
        sql << res if args && args[:return_sql]
      end
    end

    return sql if args && args[:return_sql]
    return nil
  end
end
