Baza.load_driver("mysql")

class Baza::Driver::Mysql2 < Baza::MysqlBaseDriver
  AutoAutoloader.autoload_sub_classes(self, __FILE__)

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

  def initialize(db)
    super

    @opts = @db.opts

    require "monitor"
    @mutex = Monitor.new

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

  # Cleans the wref-map holding the tables.
  def clean
    tables.clean if tables
  end

  # Respawns the connection to the MySQL-database.
  def reconnect
    @mutex.synchronize do
      args = {
        host: @db.opts[:host],
        username: @db.opts[:user],
        password: @db.opts[:pass],
        database: @db.opts[:db],
        port: @port,
        symbolize_keys: true,
        cache_rows: false
      }

      # Symbolize keys should also be given here, else table-data wont be symbolized for some reason - knj.
      @query_args = {symbolize_keys: true}
      @query_args[:cast] = false unless @db.opts[:type_translation]
      @query_args.merge!(@db.opts[:query_args]) if @db.opts[:query_args]

      pos_args = [:as, :async, :cast_booleans, :database_timezone, :application_timezone, :cache_rows, :connect_flags, :cast]
      pos_args.each do |key|
        args[key] = @db.opts[key] if @db.opts.key?(key)
      end

      args[:as] = :array

      tries = 0
      begin
        tries += 1
        if @db.opts[:conn]
          @conn = @db.opts[:conn]
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
  def query_ubuf(str, _args = nil, &_blk)
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
    @db = nil
    @mutex = nil
    @encoding = nil
    @query_args = nil
    @port = nil
  end
end
