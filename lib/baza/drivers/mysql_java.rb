class Baza::Driver::MysqlJava < Baza::BaseSqlDriver
  path = "#{File.dirname(__FILE__)}/mysql_java"

  autoload :Table, "#{path}/table"
  autoload :Tables, "#{path}/tables"
  autoload :Column, "#{path}/column"
  autoload :Columns, "#{path}/columns"
  autoload :Index, "#{path}/index"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"
  autoload :ResultUnbuffered, "#{path}/result_unbuffered"
  autoload :Sqlspecs, "#{path}/sqlspecs"

  attr_reader :conn, :conns

  #Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "Java::ComMysqlJdbc::JDBC4Connection"
      return {
        type: :success,
        args: {
          type: :mysql_java,
          conn: args[:object],
          query_args: {
            as: :hash,
            symbolize_keys: true
          }
        }
      }
    end

    return nil
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

    @java_rs_data = {}
    reconnect
  end

  #This method handels the closing of statements and results for the Java MySQL-mode.
  def java_mysql_resultset_killer(id)
    data = @java_rs_data[id]
    return nil unless data

    data[:res].close
    data[:stmt].close
    @java_rs_data.delete(id)
  end

  #Cleans the wref-map holding the tables.
  def clean
    tables.clean if tables
  end

  #Respawns the connection to the MySQL-database.
  def reconnect
    @mutex.synchronize do
      if @baza.opts[:conn]
        @jdbc_loaded = true
        @conn = @baza.opts[:conn]
      else
        unless @jdbc_loaded
          require "java"
          require "/usr/share/java/mysql-connector-java.jar" if File.exists?("/usr/share/java/mysql-connector-java.jar")
          import "com.mysql.jdbc.Driver"
          @jdbc_loaded = true
        end

        @conn = java.sql::DriverManager.getConnection("jdbc:mysql://#{@baza.opts[:host]}:#{@port}/#{@baza.opts[:db]}?user=#{@baza.opts[:user]}&password=#{@baza.opts[:pass]}&populateInsertRowWithDefaultValues=true&zeroDateTimeBehavior=round&characterEncoding=#{@encoding}&holdResultsOpenOverStatementClose=true")
      end

      query("SET SQL_MODE = ''")
      query("SET NAMES '#{self.esc(@encoding)}'") if @encoding
    end
  end

  #Executes a query and returns the result.
  def query(str)
    str = str.to_s
    str = str.force_encoding("UTF-8") if @encoding == "utf8" and str.respond_to?(:force_encoding)
    tries = 0

    begin
      tries += 1
      @mutex.synchronize do
        stmt = conn.create_statement

        if str.match(/^\s*(delete|update|create|drop|insert\s+into|alter|truncate)\s+/i)
          begin
            stmt.execute(str)
          ensure
            stmt.close
          end

          return nil
        else
          id = nil

          begin
            res = stmt.execute_query(str)
            ret = Baza::Driver::Mysql::ResultJava.new(@baza, @opts, res)
            id = ret.__id__

            #If ID is being reused we have to free the result.
            self.java_mysql_resultset_killer(id) if @java_rs_data.key?(id)

            #Save reference to result and statement, so we can close them when they are garbage collected.
            @java_rs_data[id] = {res: res, stmt: stmt}
            ObjectSpace.define_finalizer(ret, method(:java_mysql_resultset_killer))

            return ret
          rescue => e
            res.close if res
            stmt.close
            @java_rs_data.delete(id) if ret && id

            raise e
          end
        end
      end
    rescue => e
      if tries <= 3
        if e.message == "MySQL server has gone away" || e.message == "closed MySQL connection" or e.message == "Can't connect to local MySQL server through socket"
          sleep 0.5
          reconnect
          retry
        elsif e.message.include?("No operations allowed after connection closed") or e.message == "This connection is still waiting for a result, try again once you have the result" or e.message == "Lock wait timeout exceeded; try restarting transaction"
          reconnect
          retry
        end
      end

      raise e
    end
  end

  #Executes an unbuffered query and returns the result that can be used to access the data.
  def query_ubuf(str)
    @mutex.synchronize do
      if str.match(/^\s*(delete|update|create|drop|insert\s+into)\s+/i)
        stmt = @conn.createStatement

        begin
          stmt.execute(str)
        ensure
          stmt.close
        end

        return nil
      else
        stmt = @conn.create_statement(java.sql.ResultSet.TYPE_FORWARD_ONLY, java.sql.ResultSet.CONCUR_READ_ONLY)
        stmt.fetch_size = java.lang.Integer::MIN_VALUE

        begin
          res = stmt.executeQuery(str)
          ret = Baza::Driver::MysqlJava::UnbufferedResult.new(@baza, @opts, res)

          #Save reference to result and statement, so we can close them when they are garbage collected.
          @java_rs_data[ret.__id__] = {res: res, stmt: stmt}
          ObjectSpace.define_finalizer(ret, method("java_mysql_resultset_killer"))

          return ret
        rescue => e
          res.close if res
          stmt.close
          raise e
        end
      end
    end
  end

  #Returns the last inserted ID for the connection.
  def last_id
    data = query("SELECT LAST_INSERT_ID() AS id").fetch
    return data[:id].to_i if data[:id]
    raise "Could not figure out last inserted ID."
  end

  #Closes the connection threadsafe.
  def close
    @mutex.synchronize { @conn.close }
  end

  #Destroyes the connection.
  def destroy
    @conn = nil
    @baza = nil
    @mutex = nil
    @encoding = nil
    @query_args = nil
    @port = nil
  end

  #Inserts multiple rows in a table. Can return the inserted IDs if asked to in arguments.
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
      sql << "`#{self.esc_col(col_name)}`"
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
        hash.each do |key, val|
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

    self.query(sql)

    if args && args[:return_id]
      first_id = self.last_id
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
