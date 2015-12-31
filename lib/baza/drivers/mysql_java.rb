Baza.load_driver("mysql")

class Baza::Driver::MysqlJava < Baza::JdbcDriver
  path = "#{File.dirname(__FILE__)}/mysql_java"

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

  attr_reader :conn, :conns

  # Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "Java::ComMysqlJdbc::JDBC4Connection"
      return {
        type: :success,
        args: {
          type: :mysql_java,
          conn: args[:object]
        }
      }
    end

    nil
  end

  def initialize(db)
    super

    @opts = @db.opts

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

    @java_rs_data = {}
    reconnect
  end

  # Respawns the connection to the MySQL-database.
  def reconnect
    @mutex.synchronize do
      if @db.opts[:conn]
        @jdbc_loaded = true
        @conn = @db.opts[:conn]
      else
        com.mysql.jdbc.Driver
        @conn = java.sql::DriverManager.getConnection("jdbc:mysql://#{@db.opts[:host]}:#{@port}/#{@db.opts[:db]}?user=#{@db.opts[:user]}&password=#{@db.opts[:pass]}&populateInsertRowWithDefaultValues=true&zeroDateTimeBehavior=round&characterEncoding=#{@encoding}&holdResultsOpenOverStatementClose=true")
      end

      query_no_result_set("SET SQL_MODE = ''")
      query_no_result_set("SET NAMES '#{esc(@encoding)}'") if @encoding
    end
  end

  # Returns the last inserted ID for the connection.
  def last_id
    data = query("SELECT LAST_INSERT_ID() AS id").fetch
    return data[:id].to_i if data[:id]
    raise "Could not figure out last inserted ID."
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
      sql << "`#{escape_column(col_name)}`"
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

          sql << @db.sqlval(val)
        end
      else
        hash.each do |_key, val|
          if first_key
            first_key = false
          else
            sql << ","
          end

          sql << @db.sqlval(val)
        end
      end
    end

    sql << ")"

    return sql if args && args[:return_sql]

    query_no_result_set(sql)

    if args && args[:return_id]
      first_id = last_id
      raise "Invalid ID: #{first_id}" if first_id.to_i <= 0
      ids = [first_id]
      1.upto(arr_hashes.length - 1) do |count|
        ids << first_id + count
      end

      ids_length = ids.length
      arr_hashes_length = arr_hashes.length
      raise "Invalid length (#{ids_length}, #{arr_hashes_length})." if ids_length != arr_hashes_length

      return ids
    else
      return nil
    end
  end

  def transaction
    query_no_result_set("START TRANSACTION")

    begin
      yield @db
      query_no_result_set("COMMIT")
    rescue
      query_no_result_set("ROLLBACK")
      raise
    end
  end
end
