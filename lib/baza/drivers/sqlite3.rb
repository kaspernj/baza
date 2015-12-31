# This class handels SQLite3-specific behaviour.
class Baza::Driver::Sqlite3 < Baza::BaseSqlDriver
  path = "#{File.dirname(__FILE__)}/sqlite3"

  autoload :Database, "#{path}/database"
  autoload :Databases, "#{path}/databases"
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

  def self.args
    [{
      label: "Path",
      name: "path"
    }]
  end

  # Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "SQLite3::Database"
      return {
        type: :success,
        args: {
          type: :sqlite3,
          conn: args[:object]
        }
      }
    end
  end

  # Constructor. This should not be called manually.
  def initialize(db)
    super

    @path = @db.opts[:path] if @db.opts[:path]
    @mutex_statement_reader = Mutex.new

    if @db.opts[:conn]
      @conn = @db.opts[:conn]
    else
      raise "No path was given." unless @path
      require "sqlite3" unless ::Object.const_defined?(:SQLite3)

      @conn = ::SQLite3::Database.open(@path)
      @conn.type_translation = false # Type translation is always done in the C ext for SQLite3
    end
  end

  # Executes a query against the driver.
  def query(sql)
    @mutex_statement_reader.synchronize do
      return Baza::Driver::Sqlite3::Result.new(self, @conn.prepare(sql))
    end
  end

  def query_ubuf(sql)
    Baza::Driver::Sqlite3::UnbufferedResult.new(self, @conn.prepare(sql))
  end

  # Escapes a string to be safe to used in a query.
  def escape(string)
    # This code is taken directly from the documentation so we dont have to rely on the SQLite3::Database class. This way it can also be used with JRuby and IronRuby...
    # http://sqlite-ruby.rubyforge.org/classes/SQLite/Database.html
    string.to_s.gsub(/'/, "''")
  end

  # Returns the last inserted ID.
  def last_id
    return @conn.last_insert_row_id if @conn.respond_to?(:last_insert_row_id)
    query("SELECT last_insert_rowid() AS id").fetch[:id].to_i
  end

  # Closes the connection to the database.
  def close
    @mutex_statement_reader.synchronize { @conn.close }
  end

  # Starts a transaction, yields the database and commits.
  def transaction
    @conn.transaction { yield @db }
  end

  def supports_multiple_databases?
    false
  end
end
