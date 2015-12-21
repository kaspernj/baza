class Baza::Driver::Mysql2 < Baza::BaseSqlDriver
  path = "#{File.dirname(__FILE__)}/mysql2"

  autoload :Table, "#{path}/table"
  autoload :Tables, "#{path}/tables"
  autoload :Column, "#{path}/column"
  autoload :Columns, "#{path}/columns"
  autoload :Index, "#{path}/index"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"
  autoload :UnbufferedResult, "#{path}/unbuffered_result"
  autoload :Sqlspecs, "#{path}/sqlspecs"

  attr_reader :conn, :conns

  # Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "Mysql2::Client"
      return {
        type: :success,
        args: {
          type: :mysql2,
          conn: args[:object],
          query_args: {
            symbolize_keys: true
          }
        }
      }
    end

    nil
  end

  def initialize(baza)
    super

    @opts = @baza.opts

    require "monitor"
    @mutex = Monitor.new

    if @opts[:encoding]
      @encoding = @opts[:encoding]
    else
      @encoding = "utf8"
    end

    if @baza.opts.key?(:port)
      @port = @baza.opts[:port].to_i
    else
      @port = 3306
    end

    reconnect
  end

  # Cleans the wref-map holding the tables.
  def clean
    tables.clean if tables
  end

  # Respawns the connection to the MySQL-database.
  def reconnect
    @mutex.synchronize do
      args = {
        host: @baza.opts[:host],
        username: @baza.opts[:user],
        password: @baza.opts[:pass],
        database: @baza.opts[:db],
        port: @port,
        symbolize_keys: true,
        cache_rows: false
      }

      # Symbolize keys should also be given here, else table-data wont be symbolized for some reason - knj.
      @query_args = {symbolize_keys: true}
      @query_args[:cast] = false unless @baza.opts[:type_translation]
      @query_args.merge!(@baza.opts[:query_args]) if @baza.opts[:query_args]

      pos_args = [:as, :async, :cast_booleans, :database_timezone, :application_timezone, :cache_rows, :connect_flags, :cast]
      pos_args.each do |key|
        args[key] = @baza.opts[key] if @baza.opts.key?(key)
      end

      args[:as] = :array

      tries = 0
      begin
        tries += 1
        if @baza.opts[:conn]
          @conn = @baza.opts[:conn]
        else
          require "mysql2"
          @conn = Mysql2::Client.new(args)
        end
      rescue => e
        if tries <= 3
          if e.message == "Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock' (111)"
            sleep 1
            tries += 1
            retry
          end
        end

        raise e
      end

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
        return Baza::Driver::Mysql2::Result.new(self, @conn.query(str, @query_args))
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
      return Baza::Driver::Mysql2::Result.new(self, @conn.query(str, @query_args.merge(stream: true)))
    end
  end

  # Escapes a string to be safe to use in a query.
  def escape(string)
    @conn.escape(string.to_s)
  end

  # Returns the last inserted ID for the connection.
  def last_id
    @mutex.synchronize { return @conn.last_id.to_i }
  end

  # Closes the connection threadsafe.
  def close
    @mutex.synchronize { @conn.close }
  end

  # Destroyes the connection.
  def destroy
    @conn = nil
    @baza = nil
    @mutex = nil
    @encoding = nil
    @query_args = nil
    @port = nil
  end

  # Inserts multiple rows in a table. Can return the inserted IDs if asked to in arguments.
  def insert_multi(tablename, arr_hashes, args = nil)
    sql = "INSERT INTO `#{tablename}` ("

    first = true
    if args && args[:keys]
      keys = args[:keys]
    elsif arr_hashes.first.is_a?(Hash)
      keys = arr_hashes.first.keys
    else
      raise "Could not figure out keys."
    end

    keys.each do |col_name|
      sql << "," unless first
      first = false if first
      sql << "`#{esc_col(col_name)}`"
    end

    sql << ") VALUES ("

    first = true
    arr_hashes.each do |hash|
      if first
        first = false
      else
        sql << "),("
      end

      first_key = true
      if hash.is_a?(Array)
        hash.each do |val|
          if first_key
            first_key = false
          else
            sql << ","
          end

          sql << @baza.sqlval(val)
        end
      else
        hash.each do |_key, val|
          if first_key
            first_key = false
          else
            sql << ","
          end

          sql << @baza.sqlval(val)
        end
      end
    end

    sql << ")"

    return sql if args && args[:return_sql]

    query(sql)

    if args && args[:return_id]
      first_id = last_id
      raise "Invalid ID: #{first_id}" if first_id.to_i <= 0
      ids = [first_id]
      1.upto(arr_hashes.length - 1) do |count|
        ids << first_id + count
      end

      ids_length = ids.length
      arr_hashes_length = arr_hashes.length
      raise "Invalid length (#{ids_length}, #{arr_hashes_length})." unless ids_length == arr_hashes_length

      return ids
    else
      return nil
    end
  end

  def transaction
    @baza.q("START TRANSACTION")

    begin
      yield @baza
      @baza.q("COMMIT")
    rescue
      @baza.q("ROLLBACK")
      raise
    end
  end
end
