Baza.load_driver("mysql")

class Baza::Driver::MysqlJava < Baza::JdbcDriver
  AutoAutoloader.autoload_sub_classes(self, __FILE__)

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

  def self.args
    [{
      label: "Host",
      name: "host"
    }, {
      label: "Port",
      name: "port"
    }, {
      label: "Username",
      name: "user"
    }, {
      label: "Password",
      name: "pass"
    }, {
      label: "Database",
      name: "db"
    }, {
      label: "Encoding",
      name: "encoding"
    }]
  end

  def initialize(db)
    super

    @opts = @db.opts
    @encoding = @opts[:encoding] || "utf8"

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
        @conn = @db.opts.fetch(:conn)
      else
        com.mysql.cj.jdbc.Driver
        @conn = java.sql::DriverManager.getConnection(jdbc_connect_command)
      end

      query_no_result_set("SET SQL_MODE = ''")
      query_no_result_set("SET NAMES '#{esc(@encoding)}'") if @encoding
    end
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
  def insert_multi(tablename, arr_hashes, args = {})
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
      sql << quote_column(col_name)
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

          sql << @db.quote_value(val)
        end
      else
        hash.each do |_key, val|
          if first_key
            first_key = false
          else
            sql << ","
          end

          sql << @db.quote_value(val)
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

private

  def jdbc_connect_command
    conn_options = {
      "populateInsertRowWithDefaultValues" => true,
      "zeroDateTimeBehavior" => "round",
      "holdResultsOpenOverStatementClose" => true
    }

    conn_options["user"] = @db.opts.fetch(:user) if @db.opts[:user]
    conn_options["password"] = @db.opts.fetch(:pass) if db.opts[:pass]
    conn_options["characterEncoding"] = @encoding if @encoding

    conn_command = "jdbc:mysql://#{@db.opts.fetch(:host)}:#{@port}/#{@db.opts.fetch(:db)}?"
    first = true
    conn_options.each do |key, value|
      conn_command << "&" unless first
      first = false if first
      conn_command << "#{key}=#{value}"
    end

    conn_command
  end
end
