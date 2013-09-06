#This class handels SQLite3-specific behaviour.
class Baza::Driver::Sqlite3
  attr_reader :baza, :conn, :sep_table, :sep_col, :sep_val, :symbolize
  attr_accessor :tables, :cols, :indexes
  
  #Helper to enable automatic registering of database using Baza::Db.from_object
  def self.from_object(args)
    if args[:object].class.name == "SQLite3::Database"
      return {
        :type => :success,
        :args => {
          :type => :sqlite3,
          :conn => args[:object]
        }
      }
    end
    
    return nil
  end
  
  #Constructor. This should not be called manually.
  def initialize(baza_db_obj)
    @sep_table = "`"
    @sep_col = "`"
    @sep_val = "'"
    
    @baza_db = baza_db_obj
    @path = @baza_db.opts[:path] if @baza_db.opts[:path]
    @path = @baza_db.opts["path"] if @baza_db.opts["path"]
    
    @baza_db.opts[:subtype] = "java" if !@baza_db.opts.key?(:subtype) and RUBY_ENGINE == "jruby"
    
    if @baza_db.opts[:conn]
      @conn = @baza_db.opts[:conn]
    else
      raise "No path was given." if !@path
      
      if @baza_db.opts[:subtype] == "java"
        if @baza_db.opts[:sqlite_driver]
          require @baza_db.opts[:sqlite_driver]
        else
          require "#{File.dirname(__FILE__)}/../../../jruby/sqlitejdbc-v056.jar"
        end
        
        require "java"
        import "org.sqlite.JDBC"
        @conn = java.sql.DriverManager::getConnection("jdbc:sqlite:#{@baza_db.opts[:path]}")
        @stat = @conn.createStatement
      elsif @baza_db.opts[:subtype] == "rhodes"
        @conn = SQLite3::Database.new(@path, @path)
      else
        @conn = SQLite3::Database.open(@path)
        @conn.results_as_hash = true
        @conn.type_translation = false
      end
    end
  end
  
  #Executes a query against the driver.
  def query(string)
    if @baza_db.opts[:subtype] == :rhodes
      return Baza::Driver::Sqlite3::Result.new(self, @conn.execute(string, string))
    elsif @baza_db.opts[:subtype] == :java
      begin
        return Baza::Driver::Sqlite3::ResultJava.new(self, @stat.executeQuery(string))
      rescue java.sql.SQLException => e
        if e.message.to_s.index("query does not return ResultSet") != nil
          return Baza::Driver::Sqlite3::ResultJava.new(self, nil)
        else
          raise e
        end
      end
    else
      return Baza::Driver::Sqlite3::Result.new(self, @conn.execute(string))
    end
  end
  
  #SQLite3 driver doesnt support unbuffered queries??
  alias query_ubuf query
  
  #Escapes a string to be safe to used in a query.
  def escape(string)
    #This code is taken directly from the documentation so we dont have to rely on the SQLite3::Database class. This way it can also be used with JRuby and IronRuby...
    #http://sqlite-ruby.rubyforge.org/classes/SQLite/Database.html
    return string.to_s.gsub(/'/, "''")
  end
  
  #Escapes a string to be used as a column.
  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.index(@sep_col) != nil
    return string
  end
  
  alias :esc_table :esc_col
  alias :esc :escape
  
  #Returns the last inserted ID.
  def lastID
    return @conn.last_insert_row_id if @conn.respond_to?(:last_insert_row_id)
    return self.query("SELECT last_insert_rowid() AS id").fetch[:id].to_i
  end
  
  #Closes the connection to the database.
  def close
    @conn.close
  end
  
  #Starts a transaction, yields the database and commits.
  def transaction
    @conn.transaction do
      yield(@baza_db)
    end
  end
  
  def insert_multi(tablename, arr_hashes, args = nil)
    sql = [] if args and args[:return_sql]
    
    @baza_db.transaction do
      arr_hashes.each do |hash|
        res = @baza_db.insert(tablename, hash, args)
        sql << res if args and args[:return_sql]
      end
    end
    
    return sql if args and args[:return_sql]
    return nil
  end
end

#This class handels results when running in JRuby.
class Baza::Driver::Sqlite3::ResultJava
  def initialize(driver, rs)
    @index = 0
    retkeys = driver.knjdb.opts[:return_keys]
    
    if rs
      metadata = rs.getMetaData
      columns_count = metadata.getColumnCount
      
      @rows = []
      while rs.next
        row_data = {}
        for i in (1..columns_count)
          col_name = metadata.getColumnName(i).to_sym
          row_data[col_name] = rs.getString(i)
        end
        
        @rows << row_data
      end
    end
  end
  
  #Returns a single result.
  def fetch
    return false if !@rows
    ret = @rows[@index]
    return false if !ret
    @index += 1
    return ret
  end
  
  #Loops over every result and yields them.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end

#This class handels the result when running MRI (or others).
class Baza::Driver::Sqlite3::Result
  #Constructor. This should not be called manually.
  def initialize(driver, result_array)
    @result_array = result_array
    @index = 0
  end
  
  #Returns a single result.
  def fetch
    result_hash = @result_array[@index]
    return false if !result_hash
    @index += 1
    
    ret = {}
    result_hash.each do |key, val|
      if (Float(key) rescue false)
        #do nothing.
      elsif !key.is_a?(Symbol)
        ret[key.to_sym] = val
      else
        ret[key] = val
      end
    end
    
    return ret
  end
  
  #Loops over every result yielding them.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end