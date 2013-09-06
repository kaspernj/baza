class Baza::Driver::Mysql
  attr_reader :baza, :conn, :conns, :sep_table, :sep_col, :sep_val
  attr_accessor :tables, :cols, :indexes
  
  #Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "Mysql2::Client"
      return {
        :type => :success,
        :args => {
          :type => :mysql,
          :subtype => :mysql2,
          :conn => args[:object],
          :query_args => {
            :as => :hash,
            :symbolize_keys => true
          }
        }
      }
    end
    
    return nil
  end
  
  def initialize(baza_db_obj)
    @baza_db = baza_db_obj
    @opts = @baza_db.opts
    @sep_table = "`"
    @sep_col = "`"
    @sep_val = "'"
    
    require "monitor"
    @mutex = Monitor.new
    
    if @opts[:encoding]
      @encoding = @opts[:encoding]
    else
      @encoding = "utf8"
    end
    
    if @baza_db.opts.key?(:port)
      @port = @baza_db.opts[:port].to_i
    else
      @port = 3306
    end
    
    @java_rs_data = {}
    @subtype = @baza_db.opts[:subtype]
    @subtype = :mysql if @subtype.to_s.empty?
    self.reconnect
  end
  
  #This method handels the closing of statements and results for the Java MySQL-mode.
  def java_mysql_resultset_killer(id)
    data = @java_rs_data[id]
    return nil if !data
    
    data[:res].close
    data[:stmt].close
    @java_rs_data.delete(id)
  end
  
  #Cleans the wref-map holding the tables.
  def clean
    self.tables.clean if self.tables
  end
  
  #Respawns the connection to the MySQL-database.
  def reconnect
    @mutex.synchronize do
      case @subtype
        when :mysql
          @conn = Mysql.real_connect(@baza_db.opts[:host], @baza_db.opts[:user], @baza_db.opts[:pass], @baza_db.opts[:db], @port)
        when :mysql2
          require "rubygems"
          require "mysql2"
          
          args = {
            :host => @baza_db.opts[:host],
            :username => @baza_db.opts[:user],
            :password => @baza_db.opts[:pass],
            :database => @baza_db.opts[:db],
            :port => @port,
            :symbolize_keys => true,
            :cache_rows => false
          }
          
          #Symbolize keys should also be given here, else table-data wont be symbolized for some reason - knj.
          @query_args = {:symbolize_keys => true}
          @query_args.merge!(@baza_db.opts[:query_args]) if @baza_db.opts[:query_args]
          
          pos_args = [:as, :async, :cast_booleans, :database_timezone, :application_timezone, :cache_rows, :connect_flags, :cast]
          pos_args.each do |key|
            args[key] = @baza_db.opts[key] if @baza_db.opts.key?(key)
          end
          
          args[:as] = :array if @opts[:result] == "array"
          
          tries = 0
          begin
            tries += 1
            if @baza_db.opts[:conn]
              @conn = @baza_db.opts[:conn]
            else
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
        when :java
          if !@jdbc_loaded
            require "java"
            require "/usr/share/java/mysql-connector-java.jar" if File.exists?("/usr/share/java/mysql-connector-java.jar")
            import "com.mysql.jdbc.Driver"
            @jdbc_loaded = true
          end
          
          @conn = java.sql::DriverManager.getConnection("jdbc:mysql://#{@baza_db.opts[:host]}:#{@port}/#{@baza_db.opts[:db]}?user=#{@baza_db.opts[:user]}&password=#{@baza_db.opts[:pass]}&populateInsertRowWithDefaultValues=true&zeroDateTimeBehavior=round&characterEncoding=#{@encoding}&holdResultsOpenOverStatementClose=true")
          self.query("SET SQL_MODE = ''")
        else
          raise "Unknown subtype: #{@subtype} (#{@subtype.class.name})"
      end
      
      self.query("SET NAMES '#{self.esc(@encoding)}'") if @encoding
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
        case @subtype
          when :mysql
            return Baza::Driver::Mysql::Result.new(self, @conn.query(str))
          when :mysql2
            return Baza::Driver::Mysql::ResultMySQL2.new(@conn.query(str, @query_args))
          when :java
            stmt = conn.create_statement
            
            if str.match(/^\s*(delete|update|create|drop|insert\s+into|alter)\s+/i)
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
                ret = Baza::Driver::Mysql::ResultJava.new(@baza_db, @opts, res)
                id = ret.__id__
                
                #If ID is being reused we have to free the result.
                self.java_mysql_resultset_killer(id) if @java_rs_data.key?(id)
                
                #Save reference to result and statement, so we can close them when they are garbage collected.
                @java_rs_data[id] = {:res => res, :stmt => stmt}
                ObjectSpace.define_finalizer(ret, self.method(:java_mysql_resultset_killer))
                
                return ret
              rescue => e
                res.close if res
                stmt.close
                @java_rs_data.delete(id) if ret and id
                raise e
              end
            end
          else
            raise "Unknown subtype: '#{@subtype}'."
        end
      end
    rescue => e
      if tries <= 3
        if e.message == "MySQL server has gone away" or e.message == "closed MySQL connection" or e.message == "Can't connect to local MySQL server through socket"
          sleep 0.5
          self.reconnect
          retry
        elsif e.message.include?("No operations allowed after connection closed") or e.message == "This connection is still waiting for a result, try again once you have the result" or e.message == "Lock wait timeout exceeded; try restarting transaction"
          self.reconnect
          retry
        end
      end
      
      raise e
    end
  end
  
  #Executes an unbuffered query and returns the result that can be used to access the data.
  def query_ubuf(str)
    @mutex.synchronize do
      case @subtype
        when :mysql
          @conn.query_with_result = false
          return Baza::Driver::Mysql::ResultUnbuffered.new(@conn, @opts, @conn.query(str))
        when :mysql2
          return Baza::Driver::Mysql::ResultMySQL2.new(@conn.query(str, @query_args.merge(:stream => true)))
        when :java
          if str.match(/^\s*(delete|update|create|drop|insert\s+into)\s+/i)
            stmt = @conn.createStatement
            
            begin
              stmt.execute(str)
            ensure
              stmt.close
            end
            
            return nil
          else
            stmt = @conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY, java.sql.ResultSet.CONCUR_READ_ONLY)
            stmt.setFetchSize(java.lang.Integer::MIN_VALUE)
            
            begin
              res = stmt.executeQuery(str)
              ret = Baza::Driver::Mysql::ResultJava.new(@baza_db, @opts, res)
              
              #Save reference to result and statement, so we can close them when they are garbage collected.
              @java_rs_data[ret.__id__] = {:res => res, :stmt => stmt}
              ObjectSpace.define_finalizer(ret, self.method("java_mysql_resultset_killer"))
              
              return ret
            rescue => e
              res.close if res
              stmt.close
              raise e
            end
          end
        else
          raise "Unknown subtype: '#{@subtype}'"
      end
    end
  end
  
  #Escapes a string to be safe to use in a query.
  def escape_alternative(string)
    case @subtype
      when :mysql
        return @conn.escape_string(string.to_s)
      when :mysql2
        return @conn.escape(string.to_s)
      when :java
        return self.escape(string)
      else
        raise "Unknown subtype: '#{@subtype}'."
    end
  end
  
  #An alternative to the MySQL framework's escape. This is copied from the Ruby/MySQL framework at: http://www.tmtm.org/en/ruby/mysql/
  def escape(string)
    return string.to_s.gsub(/([\0\n\r\032\'\"\\])/) do
      case $1
        when "\0" then "\\0"
        when "\n" then "\\n"
        when "\r" then "\\r"
        when "\032" then "\\Z"
        else "\\#{$1}"
      end
    end
  end
  
  #Escapes a string to be safe to use as a column in a query.
  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(@sep_col)
    return string
  end
  
  alias :esc_table :esc_col
  alias :esc :escape
  
  #Returns the last inserted ID for the connection.
  def lastID
    case @subtype
      when :mysql
        @mutex.synchronize do
          return @conn.insert_id.to_i
        end
      when :mysql2
        @mutex.synchronize do
          return @conn.last_id.to_i
        end
      when :java
        data = self.query("SELECT LAST_INSERT_ID() AS id").fetch
        return data[:id].to_i if data.key?(:id)
        raise "Could not figure out last inserted ID."
    end
  end
  
  #Closes the connection threadsafe.
  def close
    @mutex.synchronize do
      @conn.close
    end
  end
  
  #Destroyes the connection.
  def destroy
    @conn = nil
    @baza_db = nil
    @mutex = nil
    @subtype = nil
    @encoding = nil
    @query_args = nil
    @port = nil
  end
  
  #Inserts multiple rows in a table. Can return the inserted IDs if asked to in arguments.
  def insert_multi(tablename, arr_hashes, args = nil)
    sql = "INSERT INTO `#{tablename}` ("
    
    first = true
    if args and args[:keys]
      keys = args[:keys]
    elsif arr_hashes.first.is_a?(Hash)
      keys = arr_hashes.first.keys
    else
      raise "Could not figure out keys."
    end
    
    keys.each do |col_name|
      sql << "," if !first
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
          
          sql << @baza_db.sqlval(val)
        end
      else
        hash.each do |key, val|
          if first_key
            first_key = false
          else
            sql << ","
          end
          
          sql << @baza_db.sqlval(val)
        end
      end
    end
    
    sql << ")"
    
    return sql if args and args[:return_sql]
    
    self.query(sql)
    
    if args and args[:return_id]
      first_id = self.lastID
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
  
  #Starts a transaction, yields the database and commits at the end.
  def transaction
    @baza_db.q("START TRANSACTION")
    
    begin
      yield(@baza_db)
      @baza_db.q("COMMIT")
    rescue
      @baza_db.q("ROLLBACK")
      raise
    end
  end
end

#This class controls the results for the normal MySQL-driver.
class Baza::Driver::Mysql::Result
  #Constructor. This should not be called manually.
  def initialize(driver, result)
    @driver = driver
    @result = result
    @mutex = Mutex.new
    
    if @result
      @keys = []
      @result.fetch_fields.each do |key|
        @keys << key.name.to_sym
      end
    end
  end
  
  #Returns a single result as a hash with symbols as keys.
  def fetch
    fetched = nil
    @mutex.synchronize do
      fetched = @result.fetch_row
    end
    
    return false if !fetched
    
    ret = {}
    count = 0
    @keys.each do |key|
      ret[key] = fetched[count]
      count += 1
    end
    
    return ret
  end
  
  #Loops over every result yielding it.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end

#This class controls the unbuffered result for the normal MySQL-driver.
class Baza::Driver::Mysql::ResultUnbuffered
  #Constructor. This should not be called manually.
  def initialize(conn, opts, result)
    @conn = conn
    @result = result
    
    if !opts.key?(:result) or opts[:result] == "hash"
      @as_hash = true
    elsif opts[:result] == "array"
      @as_hash = false
    else
      raise "Unknown type of result: '#{opts[:result]}'."
    end
  end
  
  #Lods the keys for the object.
  def load_keys
    @keys = []
    keys = @res.fetch_fields
    keys.each do |key|
      @keys << key.name.to_sym
    end
  end
  
  #Returns a single result.
  def fetch
    if @enum
      begin
        ret = @enum.next
      rescue StopIteration
        @enum = nil
        @res = nil
      end
    end
    
    if !ret and !@res and !@enum
      begin
        @res = @conn.use_result
        @enum = @res.to_enum
        ret = @enum.next
      rescue Mysql::Error
        #Reset it to run non-unbuffered again and then return false.
        @conn.query_with_result = true
        return false
      rescue StopIteration
        sleep 0.1
        retry
      end
    end
    
    if !@as_hash
      return ret
    else
      self.load_keys if !@keys
      
      ret_h = {}
      @keys.each_index do |key_no|
        ret_h[@keys[key_no]] = ret[key_no]
      end
      
      return ret_h
    end
  end
  
  #Loops over every single result yielding it.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end

#This class controls the result for the MySQL2 driver.
class Baza::Driver::Mysql::ResultMySQL2
  #Constructor. This should not be called manually.
  def initialize(result)
    @result = result
  end
  
  #Returns a single result.
  def fetch
    @enum = @result.to_enum if !@enum
    
    begin
      return @enum.next
    rescue StopIteration
      return false
    end
  end
  
  #Loops over every single result yielding it.
  def each
    @result.each do |res|
      next if !res #This sometimes happens when streaming results...
      yield(res)
    end
  end
end

#This class controls the result for the Java-MySQL-driver.
class Baza::Driver::Mysql::ResultJava
  #Constructor. This should not be called manually.
  def initialize(knjdb, opts, result)
    @baza_db = knjdb
    @result = result
    
    if !opts.key?(:result) or opts[:result] == "hash"
      @as_hash = true
    elsif opts[:result] == "array"
      @as_hash = false
    else
      raise "Unknown type of result: '#{opts[:result]}'."
    end
  end
  
  #Reads meta-data about the query like keys and count.
  def read_meta
    @result.before_first
    meta = @result.meta_data
    @count = meta.column_count
    
    @keys = []
    1.upto(@count) do |count|
      @keys << meta.column_label(count).to_sym
    end
  end
  
  def fetch
    return false if !@result
    self.read_meta if !@keys
    status = @result.next
    
    if !status
      @result = nil
      @keys = nil
      @count = nil
      return false
    end
    
    if @as_hash
      ret = {}
      1.upto(@count) do |count|
        ret[@keys[count - 1]] = @result.object(count)
      end
    else
      ret = []
      1.upto(@count) do |count|
        ret << @result.object(count)
      end
    end
    
    return ret
  end
  
  def each
    while data = self.fetch
      yield(data)
    end
  end
end