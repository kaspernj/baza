require "knjrbfw"
Knj.gem_require([:wref, :datet])

#A wrapper of several possible database-types.
#
#===Examples
# db = Baza::Db.new(:type => "mysql", :subtype => "mysql2", :db => "mysql", :user => "user", :pass => "password")
# mysql_table = db.tables['mysql']
# name = mysql_table.name
# cols = mysql_table.columns
#
# db = Baza::Db.new(:type => "sqlite3", :path => "some_db.sqlite3")
#
# db.q("SELECT * FROM users") do |data|
#   print data[:name]
# end
class Baza::Db
  attr_reader :sep_col, :sep_table, :sep_val, :opts, :conn, :conns, :int_types
  
  #Returns an array containing hashes of information about each registered driver.
  def self.drivers
    path = "#{File.dirname(__FILE__)}/drivers"
    drivers = []
    
    Dir.foreach(path) do |file|
      next if file.to_s.slice(0, 1) == "."
      fp = "#{path}/#{file}"
      next unless File.directory?(fp)
      
      driver_file = "#{fp}/#{file}.rb"
      class_name = "#{file.slice(0, 1).to_s.upcase}#{file.slice(1, file.length)}".to_sym
      
      drivers << {
        :name => file,
        :driver_path => driver_file,
        :class_name => class_name
      }
    end
    
    return drivers
  end
  
  #Tries to create a database-object based on the given object which could be a SQLite3 object or a MySQL 2 object (or other supported).
  def self.from_object(args)
    args = {:object => args} if !args.is_a?(Hash)
    raise "No :object was given." if !args[:object]
    
    Baza::Db.drivers.each do |driver|
      require driver[:driver_path]
      
      const = Baza::Driver.const_get(driver[:class_name])
      next unless const.respond_to?(:from_object)
      
      obj = const.from_object(args)
      if obj.is_a?(Hash) and obj[:type] == :success
        if obj[:args]
          return Baza::Db.new(obj[:args])
        else
          raise "Didnt know what to do."
        end
      end
    end
    
    raise "Could not figure out what to do what object of type: '#{args[:object].class.name}'."
  end
  
  def initialize(opts)
    @conn = opts.delete(:driver) if opts[:driver]
    self.opts = opts if opts != nil
    @int_types = [:int, :bigint, :tinyint, :smallint, :mediumint]
    
    if !@opts[:threadsafe]
      require "monitor"
      @mutex = Monitor.new
    end
    
    @debug = @opts[:debug]
    
    self.conn_exec do |driver|
      @sep_table = driver.sep_table
      @sep_col = driver.sep_col
      @sep_val = driver.sep_val
      @esc_driver = driver
    end
  end
  
  def args
    return @opts
  end
  
  def opts=(arr_opts)
    @opts = {}
    arr_opts.each do |key, val|
      @opts[key.to_sym] = val
    end
    
    if RUBY_PLATFORM == "java"
      @opts[:subtype] = "java"
    elsif @opts[:type] == "sqlite3" and RUBY_PLATFORM.index("mswin32") != nil
      @opts[:subtype] = "ironruby"
    end
    
    @type_cc = "#{@opts[:type].to_s.slice(0, 1).upcase}#{@opts[:type].to_s.slice(1, @opts[:type].to_s.length)}"
    self.connect
  end
  
  #Actually connects to the database. This is useually done automatically.
  def connect
    if @opts[:threadsafe]
      require "#{$knjpath}threadhandler"
      @conns = Knj::Threadhandler.new
      
      @conns.on_spawn_new do
        self.spawn
      end
      
      @conns.on_inactive do |data|
        data[:obj].close
      end
      
      @conns.on_activate do |data|
        data[:obj].reconnect
      end
    else
      @conn = self.spawn
    end
  end
  
  #Spawns a new driver (useally done automatically).
  #===Examples
  # driver_instance = db.spawn
  def spawn
    raise "No type given (#{@opts.keys.join(",")})." if !@opts[:type]
    rpath = "#{File.dirname(__FILE__)}/#{"drivers/#{@opts[:type]}/#{@opts[:type]}.rb"}"
    require rpath if (!@opts.key?(:require) or @opts[:require]) and File.exists?(rpath)
    return Baza::Driver.const_get(@type_cc).new(self)
  end
  
  #Registers a driver to the current thread.
  def get_and_register_thread
    raise "KnjDB-object is not in threadding mode." if !@conns
    
    thread_cur = Thread.current
    tid = self.__id__
    thread_cur[:knjdb] = {} if !thread_cur[:knjdb]
    
    if thread_cur[:knjdb][tid]
      #An object has already been spawned - free that first to avoid endless "used" objects.
      self.free_thread
    end
    
    thread_cur[:knjdb][tid] = @conns.get_and_lock if !thread_cur[:knjdb][tid]
    
    #If block given then be ensure to free thread after yielding.
    if block_given?
      begin
        yield
      ensure
        self.free_thread
      end
    end
  end
  
  #Frees the current driver from the current thread.
  def free_thread
    thread_cur = Thread.current
    tid = self.__id__
    
    if thread_cur[:knjdb] and thread_cur[:knjdb].key?(tid)
      db = thread_cur[:knjdb][tid]
      thread_cur[:knjdb].delete(tid)
      @conns.free(db) if @conns
    end
  end
  
  #Clean up various memory-stuff if possible.
  def clean
    if @conns
      @conns.objects.each do |data|
        data[:object].clean if data[:object].respond_to?("clean")
      end
    elsif @conn
      @conn.clean if @conn.respond_to?("clean")
    end
  end
  
  #The all driver-database-connections.
  def close
    @conn.close if @conn
    @conns.destroy if @conns
    
    @conn = nil
    @conns = nil
  end
  
  #Clones the current database-connection with possible extra arguments.
  def clone_conn(args = {})
    conn = Baza::Db.new(@opts.clone.merge(args))
    
    if block_given?
      begin
        yield(conn)
      ensure
        conn.close
      end
      
      return nil
    else
      return conn
    end
  end
  
  COPY_TO_ALLOWED_ARGS = [:tables, :debug]
  #Copies the content of the current database to another instance of Baza::Db.
  def copy_to(db, args = {})
    debug = args[:debug]
    raise "No tables given." if !data[:tables]
    
    data[:tables].each do |table|
      table_args = nil
      table_args = args[:tables][table[:name.to_sym]] if args and args[:tables] and args[:tables][table[:name].to_sym]
      next if table_args and table_args[:skip]
      table.delete(:indexes) if table.key?(:indexes) and args[:skip_indexes]
      
      table_name = table.delete(:name)
      puts "Creating table: '#{table_name}'." if debug
      db.tables.create(table_name, table)
      
      limit_from = 0
      limit_incr = 1000
      
      loop do
        puts "Copying rows (#{limit_from}, #{limit_incr})." if debug
        ins_arr = []
        q_rows = self.select(table_name, {}, {:limit_from => limit_from, :limit_to => limit_incr})
        while d_rows = q_rows.fetch
          col_args = nil
          
          if table_args and table_args[:columns]
            d_rows.each do |col_name, col_data|
              col_args = table_args[:columns][col_name.to_sym] if table_args and table_args[:columns]
              d_rows[col_name] = "" if col_args and col_args[:empty]
            end
          end
          
          ins_arr << d_rows
        end
        
        break if ins_arr.empty?
        
        puts "Insertering #{ins_arr.length} rows." if debug
        db.insert_multi(table_name, ins_arr)
        limit_from += limit_incr
      end
    end
  end
  
  #Returns the data of this database in a hash.
  #===Examples
  # data = db.data
  # tables_hash = data['tables']
  def data
    tables_ret = []
    tables.list.each do |name, table|
      tables_ret << table.data
    end
    
    return {
      :tables => tables_ret
    }
  end
  
  #Simply inserts data into a table.
  #
  #===Examples
  # db.insert(:users, {:name => "John", :lastname => "Doe"})
  # id = db.insert(:users, {:name => "John", :lastname => "Doe"}, :return_id => true)
  # sql = db.insert(:users, {:name => "John", :lastname => "Doe"}, :return_sql => true) #=> "INSERT INTO `users` (`name`, `lastname`) VALUES ('John', 'Doe')"
  def insert(tablename, arr_insert, args = nil)
    sql = "INSERT INTO #{@sep_table}#{self.esc_table(tablename)}#{@sep_table}"
    
    if !arr_insert or arr_insert.empty?
      #This is the correct syntax for inserting a blank row in MySQL.
      if @opts[:type].to_s == "mysql"
        sql << " VALUES ()"
      elsif @opts[:type].to_s == "sqlite3"
        sql << " DEFAULT VALUES"
      else
        raise "Unknown database-type: '#{@opts[:type]}'."
      end
    else
      sql << " ("
      
      first = true
      arr_insert.each do |key, value|
        if first
          first = false
        else
          sql << ", "
        end
        
        sql << "#{@sep_col}#{self.esc_col(key)}#{@sep_col}"
      end
      
      sql << ") VALUES ("
      
      first = true
      arr_insert.each do |key, value|
        if first
          first = false
        else
          sql << ", "
        end
        
        sql << self.sqlval(value)
      end
      
      sql << ")"
    end
    
    return sql if args and args[:return_sql]
    
    self.conn_exec do |driver|
      begin
        driver.query(sql)
      rescue => e
        self.add_sql_to_error(e, sql) if @opts[:sql_to_error]
        raise e
      end
      
      return driver.lastID if args and args[:return_id]
      return nil
    end
  end
  
  def add_sql_to_error(error, sql)
    error.message << " (SQL: #{sql})"
  end
  
  #Returns the correct SQL-value for the given value. If it is a number, then just the raw number as a string will be returned. nil's will be NULL and strings will have quotes and will be escaped.
  def sqlval(val)
    return @conn.sqlval(val) if @conn.respond_to?(:sqlval)
    
    if val.is_a?(Fixnum) or val.is_a?(Integer)
      return val.to_s
    elsif val == nil
      return "NULL"
    elsif val.is_a?(Date)
      return "#{@sep_val}#{Datet.in(val).dbstr(:time => false)}#{@sep_val}"
    elsif val.is_a?(Time) or val.is_a?(DateTime)
      return "#{@sep_val}#{Datet.in(val).dbstr}#{@sep_val}"
    else
      return "#{@sep_val}#{self.escape(val)}#{@sep_val}"
    end
  end
  
  #Simply and optimal insert multiple rows into a table in a single query. Uses the drivers functionality if supported or inserts each row manually.
  #
  #===Examples
  # db.insert_multi(:users, [
  #   {:name => "John", :lastname => "Doe"},
  #   {:name => "Kasper", :lastname => "Johansen"}
  # ])
  def insert_multi(tablename, arr_hashes, args = nil)
    return false if arr_hashes.empty?
    
    if @esc_driver.respond_to?(:insert_multi)
      if args and args[:return_sql]
        res =  @esc_driver.insert_multi(tablename, arr_hashes, args)
        if res.is_a?(String)
          return [res]
        elsif res.is_a?(Array)
          return res
        else
          raise "Unknown result: '#{res.class.name}'."
        end
      end
      
      self.conn_exec do |driver|
        return driver.insert_multi(tablename, arr_hashes, args)
      end
    else
      ret = []
      arr_hashes.each do |hash|
        if ret
          ret << self.insert(tablename, hash, args)
        else
          self.insert(tablename, hash, args)
        end
      end
      
      if ret
        return ret
      else
        return nil
      end
    end
  end
  
  #Simple updates rows.
  #
  #===Examples
  # db.update(:users, {:name => "John"}, {:lastname => "Doe"})
  def update(tablename, hash_update, arr_terms = {}, args = nil)
    raise "'hash_update' was not a hash: '#{hash_update.class.name}'." if !hash_update.is_a?(Hash)
    return false if hash_update.empty?
    
    sql = ""
    sql << "UPDATE #{@sep_col}#{tablename}#{@sep_col} SET "
    
    first = true
    hash_update.each do |key, value|
      if first
        first = false
      else
        sql << ", "
      end
      
      #Convert dates to valid dbstr.
      value = self.date_out(value) if value.is_a?(Datet) or value.is_a?(Time)
      
      sql << "#{@sep_col}#{self.esc_col(key)}#{@sep_col} = "
      sql << self.sqlval(value)
    end
    
    if arr_terms and arr_terms.length > 0
      sql << " WHERE #{self.makeWhere(arr_terms)}"
    end
    
    return sql if args and args[:return_sql]
    
    self.conn_exec do |driver|
      driver.query(sql)
    end
  end
  
  #Checks if a given terms exists. If it does, updates it to match data. If not inserts the row.
  def upsert(table, data, terms, args = nil)
    row = self.select(table, terms, "limit" => 1).fetch
    
    if args and args[:buffer]
      obj = args[:buffer]
    else
      obj = self
    end
    
    if row
      obj.update(table, data, terms)
    else
      obj.insert(table, terms.merge(data))
    end
  end
  
  SELECT_ARGS_ALLOWED_KEYS = [:limit, :limit_from, :limit_to]
  #Makes a select from the given arguments: table-name, where-terms and other arguments as limits and orders. Also takes a block to avoid raping of memory.
  def select(tablename, arr_terms = nil, args = nil, &block)
    #Set up vars.
    sql = ""
    args_q = nil
    select_sql = "*"
    
    #Give 'cloned_ubuf' argument to 'q'-method.
    if args and args[:cloned_ubuf]
      args_q = {:cloned_ubuf => true}
    end
    
    #Set up IDQuery-stuff if that is given in arguments.
    if args and args[:idquery]
      if args[:idquery] == true
        select_sql = "`id`"
        col = :id
      else
        select_sql = "`#{self.esc_col(args[:idquery])}`"
        col = args[:idquery]
      end
    end
    
    sql = "SELECT #{select_sql} FROM #{@sep_table}#{tablename}#{@sep_table}"
    
    if arr_terms != nil and !arr_terms.empty?
      sql << " WHERE #{self.makeWhere(arr_terms)}"
    end
    
    if args != nil
      if args[:orderby]
        sql << " ORDER BY #{args[:orderby]}"
      end
      
      if args[:limit]
        sql << " LIMIT #{args[:limit]}"
      end
      
      if args[:limit_from] and args[:limit_to]
        raise "'limit_from' was not numeric: '#{args[:limit_from]}'." if !(Float(args[:limit_from]) rescue false)
        raise "'limit_to' was not numeric: '#{args[:limit_to]}'." if !(Float(args[:limit_to]) rescue false)
        sql << " LIMIT #{args[:limit_from]}, #{args[:limit_to]}"
      end
    end
    
    #Do IDQuery if given in arguments.
    if args and args[:idquery]
      res = Baza::Idquery.new(:db => self, :table => tablename, :query => sql, :col => col, &block)
    else
      res = self.q(sql, args_q, &block)
    end
    
    #Return result if a block wasnt given.
    if block
      return nil
    else
      return res
    end
  end
  
  #Returns a single row from a database.
  #
  #===Examples
  # row = db.single(:users, {:lastname => "Doe"})
  def single(tablename, arr_terms = nil, args = {})
    args[:limit] = 1
    
    #Experienced very weird memory leak if this was not done by block. Maybe bug in Ruby 1.9.2? - knj
    self.select(tablename, arr_terms, args) do |data|
      return data
    end
    
    return false
  end
  
  alias :selectsingle :single
  
  #Deletes rows from the database.
  #
  #===Examples
  # db.delete(:users, {:lastname => "Doe"})
  def delete(tablename, arr_terms, args = nil)
    sql = "DELETE FROM #{@sep_table}#{tablename}#{@sep_table}"
    
    if arr_terms != nil and !arr_terms.empty?
      sql << " WHERE #{self.makeWhere(arr_terms)}"
    end
    
    return sql if args and args[:return_sql]
    
    self.conn_exec do |driver|
      driver.query(sql)
    end
    
    return nil
  end
  
  #Internally used to generate SQL.
  #
  #===Examples
  # sql = db.makeWhere({:lastname => "Doe"}, driver_obj)
  def makeWhere(arr_terms, driver = nil)
    sql = ""
    
    first = true
    arr_terms.each do |key, value|
      if first
        first = false
      else
        sql << " AND "
      end
      
      if value.is_a?(Array)
        raise "Array for column '#{key}' was empty." if value.empty?
        sql << "#{@sep_col}#{key}#{@sep_col} IN (#{Knj::ArrayExt.join(:arr => value, :sep => ",", :surr => "'", :callback => proc{|ele| self.esc(ele)})})"
      elsif value.is_a?(Hash)
        raise "Dont know how to handle hash."
      else
        sql << "#{@sep_col}#{key}#{@sep_col} = #{self.sqlval(value)}"
      end
    end
    
    return sql
  end
  
  #Returns a driver-object based on the current thread and free driver-objects.
  #
  #===Examples
  # db.conn_exec do |driver|
  #   str = driver.escape('something̈́')
  # end
  def conn_exec
    if tcur = Thread.current and tcur[:knjdb]
      tid = self.__id__
      
      if tcur[:knjdb].key?(tid)
        yield(tcur[:knjdb][tid])
        return nil
      end
    end
    
    if @conns
      conn = @conns.get_and_lock
      
      begin
        yield(conn)
        return nil
      ensure
        @conns.free(conn)
      end
    elsif @conn
      @mutex.synchronize do
        yield(@conn)
        return nil
      end
    end
    
    raise "Could not figure out how to find a driver to use?"
  end
  
  #Executes a query and returns the result.
  #
  #===Examples
  # res = db.query('SELECT * FROM users')
  # while data = res.fetch
  #   print data[:name]
  # end
  def query(string)
    if @debug
      print "SQL: #{string}\n"
      
      if @debug.is_a?(Fixnum) and @debug >= 2
        print caller.join("\n")
        print "\n"
      end
    end
    
    begin
      self.conn_exec do |driver|
        return driver.query(string)
      end
    rescue => e
      e.message << " (SQL: #{string})" if @opts[:sql_to_error]
      raise e
    end
  end
  
  #Execute an ubuffered query and returns the result.
  #
  #===Examples
  # db.query_ubuf('SELECT * FROM users') do |data|
  #   print data[:name]
  # end
  def query_ubuf(string, &block)
    ret = nil
    
    self.conn_exec do |driver|
      ret = driver.query_ubuf(string, &block)
    end
    
    if block
      ret.each(&block)
      return nil
    end
    
    return ret
  end
  
  #Clones the connection, executes the given block and closes the connection again.
  #
  #===Examples
  # db.cloned_conn do |conn|
  #   conn.q('SELCET * FROM users') do |data|
  #     print data[:name]
  #   end
  # end
  def cloned_conn(args = nil, &block)
    clone_conn_args = {
      :threadsafe => false
    }
    
    clone_conn_args.merge!(args[:clone_args]) if args and args[:clone_args]
    dbconn = self.clone_conn(clone_conn_args)
    
    begin
      yield(dbconn)
    ensure
      dbconn.close
    end
  end
  
  #Executes a query and returns the result. If a block is given the result is iterated over that block instead and it returns nil.
  #
  #===Examples
  # db.q('SELECT * FROM users') do |data|
  #   print data[:name]
  # end
  def q(str, args = nil, &block)
    #If the query should be executed in a new connection unbuffered.
    if args
      if args[:cloned_ubuf]
        raise "No block given." if !block
        
        self.cloned_conn(:clone_args => args[:clone_args]) do |cloned_conn|
          ret = cloned_conn.query_ubuf(str)
          ret.each(&block)
        end
        
        return nil
      else
        raise "Invalid arguments given: '#{args}'."
      end
    end
    
    ret = self.query(str)
    
    if block
      ret.each(&block)
      return nil
    end
    
    return ret
  end
  
  #Yields a query-buffer and flushes at the end of the block given.
  def q_buffer(args = {}, &block)
    Baza::QueryBuffer.new(args.merge(:db => self), &block)
    return nil
  end
  
  #Returns the last inserted ID.
  #
  #===Examples
  # id = db.last_id
  def lastID
    self.conn_exec do |driver|
      return driver.lastID
    end
  end
  
  alias :last_id :lastID
  
  #Escapes a string to be safe-to-use in a query-string.
  #
  #===Examples
  # db.q("INSERT INTO users (name) VALUES ('#{db.esc('John')}')")
  def escape(string)
    return @esc_driver.escape(string)
  end
  
  alias :esc :escape
  
  #Escapes the given string to be used as a column.
  def esc_col(str)
    return @esc_driver.esc_col(str)
  end
  
  #Escapes the given string to be used as a table.
  def esc_table(str)
    return @esc_driver.esc_table(str)
  end
  
  #Returns a string which can be used in SQL with the current driver.
  #===Examples
  # str = db.date_out(Time.now) #=> "2012-05-20 22:06:09"
  def date_out(date_obj = Datet.new, args = {})
    if @esc_driver.respond_to?(:date_out)
      return @esc_driver.date_out(date_obj, args)
    end
    
    return Datet.in(date_obj).dbstr(args)
  end
  
  #Takes a valid date-db-string and converts it into a Datet.
  #===Examples
  # db.date_in('2012-05-20 22:06:09') #=> 2012-05-20 22:06:09 +0200
  def date_in(date_obj)
    if @esc_driver.respond_to?(:date_in)
      return @esc_driver.date_in(date_obj)
    end
    
    return Datet.in(date_obj)
  end
  
  #Returns the table-module and spawns it if it isnt already spawned.
  def tables
    if !@tables
      require "#{File.dirname(__FILE__)}/drivers/#{@opts[:type]}/#{@opts[:type]}_tables" if (!@opts.key?(:require) or @opts[:require])
      @tables = Baza::Driver.const_get(@type_cc).const_get(:Tables).new(
        :db => self
      )
    end
    
    return @tables
  end
  
  #Returns the columns-module and spawns it if it isnt already spawned.
  def cols
    if !@cols
      require "#{File.dirname(__FILE__)}/drivers/#{@opts[:type]}/#{@opts[:type]}_columns" if (!@opts.key?(:require) or @opts[:require])
      @cols = Baza::Driver.const_get(@type_cc).const_get(:Columns).new(
        :db => self
      )
    end
    
    return @cols
  end
  
  #Returns the index-module and spawns it if it isnt already spawned.
  def indexes
    if !@indexes
      require "#{File.dirname(__FILE__)}/drivers/#{@opts[:type]}/#{@opts[:type]}_indexes" if (!@opts.key?(:require) or @opts[:require])
      @indexes = Baza::Driver.const_get(@type_cc).const_get(:Indexes).new(
        :db => self
      )
    end
    
    return @indexes
  end
  
  #Returns the SQLSpec-module and spawns it if it isnt already spawned.
  def sqlspecs
    if !@sqlspecs
      require "#{File.dirname(__FILE__)}/drivers/#{@opts[:type]}/#{@opts[:type]}_sqlspecs" if (!@opts.key?(:require) or @opts[:require])
      @sqlspecs = Baza::Driver.const_get(@type_cc).const_get(:Sqlspecs).new(
        :db => self
      )
    end
    
    return @sqlspecs
  end
  
  #Beings a transaction and commits when the block ends.
  #
  #===Examples
  # db.transaction do |db|
  #   db.insert(:users, {:name => "John"})
  #   db.insert(:users, {:name => "Kasper"})
  # end
  def transaction(&block)
    self.conn_exec do |driver|
      driver.transaction(&block)
    end
  end
  
  #Optimizes all tables in the database.
  def optimize(args = nil)
    STDOUT.puts "Beginning optimization of database." if @debug or (args and args[:debug])
    self.tables.list do |table|
      STDOUT.puts "Optimizing table: '#{table.name}'." if @debug or (args and args[:debug])
      table.optimize
    end
    
    return nil
  end
  
  #Proxies the method to the driver.
  #
  #===Examples
  # db.method_on_driver
  def method_missing(method_name, *args)
    self.conn_exec do |driver|
      if driver.respond_to?(method_name.to_sym)
        return driver.send(method_name, *args)
      end
    end
    
    raise "Method not found: #{method_name}"
  end
end

#Subclass that contains all the drivers as further subclasses.
class Baza::Driver
  
end