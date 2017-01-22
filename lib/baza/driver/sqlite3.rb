# This class handels SQLite3-specific behaviour.
class Baza::Driver::Sqlite3 < Baza::BaseSqlDriver
  AutoAutoloader.autoload_sub_classes(self, __FILE__)

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

  def enable_foreign_key_support
    return true if @foreign_key_support_enabled

    @db.query("PRAGMA foreign_keys = ON")
    @foreign_key_support_enabled = true
    true
  end

  def foreign_key_support?
    false
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
