# This class handels SQLite3-specific behaviour.
class Baza::Driver::Sqlite3Java < Baza::JdbcDriver
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

  # Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "Java::OrgSqlite::SQLiteConnection"
      return {
        type: :success,
        args: {
          type: :sqlite3_java,
          conn: args[:object]
        }
      }
    end
  end

  # Constructor. This should not be called manually.
  def initialize(baza_db)
    super

    @path = @baza.opts[:path] if @baza.opts[:path]
    @preload_results = true

    if @baza.opts[:conn]
      @conn = @baza.opts[:conn]
    else
      org.sqlite.JDBC
      reconnect
    end
  end

  def reconnect
    raise "No path was given." unless @path

    @stmt = nil
    @conn = java.sql.DriverManager.getConnection("jdbc:sqlite:#{@path}")
  end

  # Escapes a string to be safe to used in a query.
  def escape(string)
    # This code is taken directly from the documentation so we dont have to rely on the SQLite3::Database class. This way it can also be used with JRuby and IronRuby...
    # http://sqlite-ruby.rubyforge.org/classes/SQLite/Database.html
    string.to_s.gsub(/'/, "''")
  end

  # Returns the last inserted ID.
  def last_id
    query("SELECT LAST_INSERT_ROWID() AS id").fetch[:id].to_i
  end

  def transaction
    query_no_result_set("BEGIN TRANSACTION")

    begin
      yield @baza
      query_no_result_set("COMMIT")
    rescue
      query_no_result_set("ROLLBACK")
      raise
    end
  end
end
