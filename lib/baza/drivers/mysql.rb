class Baza::Driver::Mysql < Baza::MysqlBaseDriver
  path = "#{File.dirname(__FILE__)}/mysql"

  autoload :Database, "#{path}/database"
  autoload :Databases, "#{path}/databases"
  autoload :Table, "#{path}/table"
  autoload :Tables, "#{path}/tables"
  autoload :Column, "#{path}/column"
  autoload :Columns, "#{path}/columns"
  autoload :Index, "#{path}/index"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"
  autoload :UnbufferedResult, "#{path}/unbuffered_result"
  autoload :Sqlspecs, "#{path}/sqlspecs"

  attr_reader :conn

  def self.from_object(args)
    raise "Mysql does not support auth extraction" if args[:object].class.name == "Mysql"
  end

  def initialize(db)
    super

    @opts = @db.opts

    require "monitor"
    @mutex = Monitor.new

    if db.opts[:conn]
      @conn = db.opts[:conn]
    else
      if @opts[:encoding]
        @encoding = @opts[:encoding]
      else
        @encoding = "utf8"
      end

      if @db.opts.key?(:port)
        @port = @db.opts[:port].to_i
      else
        @port = 3306
      end

      reconnect
    end
  end

  # Cleans the wref-map holding the tables.
  def clean
    tables.clean if tables
  end

  # Respawns the connection to the MySQL-database.
  def reconnect
    @mutex.synchronize do
      require "mysql" unless ::Object.const_defined?(:Mysql)
      @conn = ::Mysql.real_connect(@db.opts[:host], @db.opts[:user], @db.opts[:pass], @db.opts[:db], @port)
      query("SET NAMES '#{esc(@encoding)}'") if @encoding
    end
  end

  # Executes a query and returns the result.
  def query(str)
    str = str.to_s
    str = str.force_encoding("UTF-8") if @encoding == "utf8" && str.respond_to?(:force_encoding)
    tries = 0

    begin
      tries += 1
      @mutex.synchronize do
        return Baza::Driver::Mysql::Result.new(self, @conn.query(str))
      end
    rescue => e
      if tries <= 3
        if e.message == "MySQL server has gone away" || e.message == "closed MySQL connection" || e.message == "Can't connect to local MySQL server through socket"
          sleep 0.5
          reconnect
          retry
        elsif e.message.include?("No operations allowed after connection closed") || e.message == "This connection is still waiting for a result, try again once you have the result" || e.message == "Lock wait timeout exceeded; try restarting transaction"
          reconnect
          retry
        end
      end

      raise e
    end
  end

  # Executes an unbuffered query and returns the result that can be used to access the data.
  def query_ubuf(str)
    @mutex.synchronize do
      @conn.query_with_result = false
      return Baza::Driver::Mysql::UnbufferedResult.new(@conn, @opts, @conn.query(str))
    end
  end

  # Escapes a string to be safe to use in a query.
  def escape_alternative(string)
    @conn.escape_string(string.to_s)
  end

  # Returns the last inserted ID for the connection.
  def last_id
    @mutex.synchronize { return @conn.insert_id.to_i }
  end

  # Closes the connection threadsafe.
  def close
    @mutex.synchronize { @conn.close }
  end

  # Destroyes the connection.
  def destroy
    @conn = nil
    @db = nil
    @mutex = nil
    @subtype = nil
    @encoding = nil
    @query_args = nil
    @port = nil
  end

  def supports_multiple_databases?
    true
  end
end
