#This class handels SQLite3-specific behaviour.
class Baza::Driver::Sqlite3Java < Baza::BaseSqlDriver
  path = "#{File.dirname(__FILE__)}/sqlite3_java"

  autoload :Table, "#{path}/table"
  autoload :Tables, "#{path}/tables"
  autoload :Column, "#{path}/column"
  autoload :Columns, "#{path}/columns"
  autoload :Index, "#{path}/index"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"
  autoload :Sqlspecs, "#{path}/sqlspecs"
  autoload :UnbufferedResult, "#{path}/unbuffered_result"

  attr_reader :mutex_statement_reader

  #Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "Java::OrgSqlite::SQLiteConnection"
      return {
        type: :success,
        args: {
          type: :sqlite3,
          conn: args[:object]
        }
      }
    end
  end

  #Constructor. This should not be called manually.
  def initialize(baza_db)
    super

    @path = @baza.opts[:path] if @baza.opts[:path]
    @mutex_statement_reader = Mutex.new

    if @baza.opts[:conn]
      @conn = @baza.opts[:conn]
      @stat = @conn.create_statement
    else
      raise "No path was given." unless @path

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
    end
  end

  #Executes a query against the driver.
  def query(sql)
    begin
      return Baza::Driver::Sqlite3Java::Result.new(self, @stat.executeQuery(sql))
    rescue java.sql.SQLException => e
      if e.message.to_s.index("query does not return ResultSet") != nil
        return Baza::Driver::Sqlite3Java::Result.new(self, nil)
      else
        raise e
      end
    end
  end

  def query_ubuf(sql)
    begin
      return Baza::Driver::Sqlite3Java::UnbufferedResult.new(self, @stat.executeQuery(sql))
    rescue java.sql.SQLException => e
      if e.message.to_s.index("query does not return ResultSet") != nil
        return Baza::Driver::Sqlite3Java::UnbufferedResult.new(self, nil)
      else
        raise e
      end
    end
  end

  #Escapes a string to be safe to used in a query.
  def escape(string)
    #This code is taken directly from the documentation so we dont have to rely on the SQLite3::Database class. This way it can also be used with JRuby and IronRuby...
    #http://sqlite-ruby.rubyforge.org/classes/SQLite/Database.html
    return string.to_s.gsub(/'/, "''")
  end

  #Returns the last inserted ID.
  def last_id
    return @conn.last_insert_row_id if @conn.respond_to?(:last_insert_row_id)
    return query("SELECT last_insert_rowid() AS id").fetch[:id].to_i
  end

  #Closes the connection to the database.
  def close
    @mutex_statement_reader.synchronize do
      @conn.close
    end
  end
end
