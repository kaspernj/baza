# A wrapper of several possible database-types.
#
#===Examples
# db = Baza::Db.new(type: :mysql2, db: "mysql", user: "user", pass: "password")
# mysql_table = db.tables['mysql']
# name = mysql_table.name
# cols = mysql_table.columns
#
# db = Baza::Db.new(type: :sqlite3, path: "some_db.sqlite3")
#
# db.q("SELECT * FROM users") do |data|
#   print data[:name]
# end
class Baza::Db
  attr_reader :sep_col, :sep_table, :sep_val, :opts, :driver, :int_types

  # Returns an array containing hashes of information about each registered driver.
  def self.drivers
    path = "#{File.dirname(__FILE__)}/drivers"
    drivers = []

    Dir.foreach(path) do |file|
      next if file.to_s.slice(0, 1) == "."
      fp = "#{path}/#{file}"
      next unless File.directory?(fp)

      driver_file = "#{fp}/#{file}.rb"
      class_name = StringCases.snake_to_camel(file).to_sym

      drivers << {
        name: file,
        driver_path: driver_file,
        class_name: class_name
      }
    end

    drivers
  end

  # Tries to create a database-object based on the given object which could be a SQLite3 object or a MySQL 2 object (or other supported).
  def self.from_object(args)
    args = {object: args} unless args.is_a?(Hash)
    raise "No :object was given." unless args[:object]

    Baza::Db.drivers.each do |driver|
      const = Baza::Driver.const_get(driver[:class_name])
      next unless const.respond_to?(:from_object)

      obj = const.from_object(args)
      next unless obj.is_a?(Hash) && obj[:type] == :success
      if obj[:args]
        new_args = obj[:args]
        new_args = new_args.merge(args[:new_args]) if args[:new_args]
        return Baza::Db.new(new_args)
      else
        raise "Didnt know what to do."
      end
    end

    raise "Could not figure out what to do what object of type: '#{args[:object].class.name}'."
  end

  def initialize(opts)
    @driver = opts.delete(:driver) if opts[:driver]
    Baza.load_driver(opts.fetch(:type))
    self.opts = opts unless opts.nil?
    @int_types = [:int, :bigint, :tinyint, :smallint, :mediumint]

    @debug = @opts[:debug]
    @driver = spawn
    @sep_table = @driver.sep_table
    @sep_col = @driver.sep_col
    @sep_val = @driver.sep_val

    return unless block_given?

    begin
      yield self
    ensure
      close
    end
  end

  def args
    @opts
  end

  def opts=(arr_opts)
    @opts = {}
    arr_opts.each do |key, val|
      @opts[key.to_sym] = val
    end

    if RUBY_PLATFORM == "java"
      @opts[:type] = :sqlite3_java if @opts[:type] == :sqlite3
      @opts[:type] = :mysql_java if @opts[:type] == :mysql || @opts[:type] == :mysql2
    end

    @type_cc = StringCases.snake_to_camel(@opts[:type])
  end

  # Spawns a new driver (useally done automatically).
  #===Examples
  # driver_instance = db.spawn
  def spawn
    raise "No type given (#{@opts.keys.join(",")})." unless @opts[:type]
    rpath = "#{File.dirname(__FILE__)}/drivers/#{@opts[:type]}.rb"
    require rpath if File.exist?(rpath)
    Baza::Driver.const_get(@type_cc).new(self)
  end

  # Registers a driver to the current thread.
  def get_and_register_thread
    raise "Baza-object is not in threadding mode" unless @conns

    thread_cur = Thread.current
    tid = __id__
    thread_cur[:baza] = {} unless thread_cur[:baza]

    if thread_cur[:baza][tid]
      # An object has already been spawned - free that first to avoid endless "used" objects.
      free_thread
    end

    thread_cur[:baza][tid] = @conns.get_and_lock unless thread_cur[:baza][tid]

    # If block given then be ensure to free thread after yielding.
    return unless block_given?

    begin
      yield
    ensure
      free_thread
    end
  end

  # The all driver-database-connections.
  def close
    @driver.close if @driver
    @driver = nil
    @closed = true
  end

  # rubocop:disable Style/TrivialAccessors
  def closed?
    # rubocop:enable Style/TrivialAccessors
    @closed
  end

  # Clones the current database-connection with possible extra arguments.
  def clone_conn(args = {})
    conn = Baza::Db.new(opts = @opts.clone.merge(args))

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
  # Copies the content of the current database to another instance of Baza::Db.
  def copy_to(db, args = {})
    debug = args[:debug]
    raise "No tables given." unless data[:tables]

    data[:tables].each do |table|
      table_args = nil
      table_args = args[:tables][table[:name]] if args && args[:tables] && args[:tables][table[:name].to_sym]
      next if table_args && table_args[:skip]
      table.delete(:indexes) if table.key?(:indexes) && args[:skip_indexes]

      table_name = table.delete(:name)
      puts "Creating table: '#{table_name}'." if debug
      db.tables.create(table_name, table)

      limit_from = 0
      limit_incr = 1000

      loop do
        puts "Copying rows (#{limit_from}, #{limit_incr})." if debug
        ins_arr = []
        select(table_name, {}, limit_from: limit_from, limit_to: limit_incr) do |d_rows|
          col_args = nil

          if table_args && table_args[:columns]
            d_rows.each do |col_name, _col_data|
              col_args = table_args[:columns][col_name] if table_args && table_args[:columns]
              d_rows[col_name] = "" if col_args && col_args[:empty]
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

  # Returns the data of this database in a hash.
  #===Examples
  # data = db.data
  # tables_hash = data['tables']
  def data
    tables_ret = []
    tables.list do |table|
      tables_ret << table.data
    end

    {tables: tables_ret}
  end

  def insert(table_name, data, args = nil)
    @driver.insert(table_name, data, args)
  end

  def add_sql_to_error(error, sql)
    error.message << " (SQL: #{sql})"
  end

  # Returns the correct SQL-value for the given value. If it is a number, then just the raw number as a string will be returned. nil's will be NULL and strings will have quotes and will be escaped.
  def sqlval(val)
    return @conn.sqlval(val) if @conn.respond_to?(:sqlval)

    if val.is_a?(Fixnum) || val.is_a?(Integer)
      return val.to_s
    elsif val == nil
      return "NULL"
    elsif val.is_a?(Date)
      return "#{@sep_val}#{Datet.in(val).dbstr(time: false)}#{@sep_val}"
    elsif val.is_a?(Time) || val.is_a?(DateTime)
      return "#{@sep_val}#{Datet.in(val).dbstr}#{@sep_val}"
    else
      return "#{@sep_val}#{escape(val)}#{@sep_val}"
    end
  end

  # Simply and optimal insert multiple rows into a table in a single query. Uses the drivers functionality if supported or inserts each row manually.
  #
  #===Examples
  # db.insert_multi(:users, [
  #   {name: "John", lastname: "Doe"},
  #   {name: "Kasper", lastname: "Johansen"}
  # ])
  def insert_multi(tablename, arr_hashes, args = nil)
    return false if arr_hashes.empty?

    if @driver.respond_to?(:insert_multi)
      if args && args[:return_sql]
        res = @driver.insert_multi(tablename, arr_hashes, args)
        if res.is_a?(String)
          return [res]
        elsif res.is_a?(Array)
          return res
        else
          raise "Unknown result: '#{res.class.name}'."
        end
      end

      @driver.insert_multi(tablename, arr_hashes, args)
    else
      transaction do
        arr_hashes.each do |hash|
          insert(tablename, hash, args)
        end
      end

      return nil
    end
  end

  # Simple updates rows.
  #
  #===Examples
  # db.update(:users, {name: "John"}, {lastname: "Doe"})
  def update(tablename, hash_update, arr_terms = {}, args = nil)
    raise "'hash_update' was not a hash: '#{hash_update.class.name}'." unless hash_update.is_a?(Hash)
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

      # Convert dates to valid dbstr.
      value = date_out(value) if value.is_a?(Datet) || value.is_a?(Time)

      sql << "#{@sep_col}#{escape_column(key)}#{@sep_col} = "
      sql << sqlval(value)
    end

    sql << " WHERE #{makeWhere(arr_terms)}" if arr_terms && arr_terms.length > 0

    return sql if args && args[:return_sql]

    query(sql)
  end

  # Checks if a given terms exists. If it does, updates it to match data. If not inserts the row.
  def upsert(table, data, terms, args = nil)
    row = single(table, terms)

    if args && args[:buffer]
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
  # Makes a select from the given arguments: table-name, where-terms and other arguments as limits and orders. Also takes a block to avoid raping of memory.
  def select(tablename, arr_terms = nil, args = nil, &block)
    # Set up vars.
    sql = ""
    args_q = nil
    select_sql = "*"

    # Give 'cloned_ubuf' argument to 'q'-method.
    args_q = {cloned_ubuf: true} if args && args[:cloned_ubuf]

    # Set up IDQuery-stuff if that is given in arguments.
    if args && args[:idquery]
      if args[:idquery] == true
        select_sql = "`id`"
        col = :id
      else
        select_sql = "`#{escape_column(args[:idquery])}`"
        col = args[:idquery]
      end
    end

    sql = "SELECT #{select_sql} FROM"

    if tablename.is_a?(Array)
      sql << " #{@sep_table}#{tablename.first}#{@sep_table}.#{@sep_table}#{tablename.last}#{@sep_table}"
    else
      sql << " #{@sep_table}#{tablename}#{@sep_table}"
    end

    if !arr_terms.nil? && !arr_terms.empty?
      sql << " WHERE #{makeWhere(arr_terms)}"
    end

    unless args.nil?
      sql << " ORDER BY #{args[:orderby]}" if args[:orderby]
      sql << " LIMIT #{args[:limit]}" if args[:limit]

      if args[:limit_from] && args[:limit_to]
        begin
          Float(args[:limit_from])
        rescue
          raise "'limit_from' was not numeric: '#{args[:limit_from]}'."
        end

        begin
          Float(args[:limit_to])
        rescue
          raise "'limit_to' was not numeric: '#{args[:limit_to]}'."
        end

        sql << " LIMIT #{args[:limit_from]}, #{args[:limit_to]}"
      end
    end

    # Do IDQuery if given in arguments.
    if args && args[:idquery]
      res = Baza::Idquery.new(db: self, table: tablename, query: sql, col: col, &block)
    else
      res = q(sql, args_q, &block)
    end

    # Return result if a block wasnt given.
    if block
      return nil
    else
      return res
    end
  end

  def count(tablename, arr_terms = nil)
    # Set up vars.
    sql = ""
    args_q = nil

    sql = "SELECT COUNT(*) AS count FROM #{@sep_table}#{tablename}#{@sep_table}"

    if !arr_terms.nil? && !arr_terms.empty?
      sql << " WHERE #{makeWhere(arr_terms)}"
    end

    q(sql).fetch.fetch(:count).to_i
  end

  # Returns a single row from a database.
  #
  #===Examples
  # row = db.single(:users, lastname: "Doe")
  def single(tablename, terms = nil, args = {})
    # Experienced very weird memory leak if this was not done by block. Maybe bug in Ruby 1.9.2? - knj
    select(tablename, terms, args.merge(limit: 1)).fetch
  end

  alias_method :selectsingle, :single

  # Deletes rows from the database.
  #
  #===Examples
  # db.delete(:users, {lastname: "Doe"})
  def delete(tablename, arr_terms, args = nil)
    sql = "DELETE FROM #{@sep_table}#{tablename}#{@sep_table}"

    if !arr_terms.nil? && !arr_terms.empty?
      sql << " WHERE #{makeWhere(arr_terms)}"
    end

    return sql if args && args[:return_sql]

    query(sql)
    nil
  end

  # Internally used to generate SQL.
  #
  #===Examples
  # sql = db.makeWhere({lastname: "Doe"}, driver_obj)
  def makeWhere(arr_terms, _driver = nil)
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
        values = value.map { |v| "'#{escape(v)}'" }.join(",")
        sql << "#{@sep_col}#{key}#{@sep_col} IN (#{values})"
      elsif value.is_a?(Hash)
        raise "Dont know how to handle hash."
      else
        sql << "#{@sep_col}#{key}#{@sep_col} = #{sqlval(value)}"
      end
    end

    sql
  end

  # Executes a query and returns the result.
  #
  #===Examples
  # res = db.query('SELECT * FROM users')
  # while data = res.fetch
  #   print data[:name]
  # end
  def query(string, args = nil, &block)
    if @debug
      print "SQL: #{string}\n"

      if @debug.is_a?(Fixnum) && @debug >= 2
        print caller.join("\n")
        print "\n"
      end
    end

    # If the query should be executed in a new connection unbuffered.
    if args && args[:cloned_ubuf]
      raise "No block given." unless block

      cloned_conn(clone_args: args[:clone_args]) do |cloned_conn|
        return cloned_conn.query_ubuf(string, args, &block)
      end

      return nil
    end

    return query_ubuf(string, args, &block) if args && args[:type] == :unbuffered

    ret = @driver.query(string)

    if block && ret
      ret.each(&block)
      return nil
    end

    ret
  end

  alias q query

  # Execute an ubuffered query and returns the result.
  #
  #===Examples
  # db.query_ubuf('SELECT * FROM users') do |data|
  #   print data[:name]
  # end
  def query_ubuf(string, args = nil, &block)
    ret = @driver.query_ubuf(string)

    if block
      ret.each(&block)
      return nil
    end

    ret
  end

  # Clones the connection, executes the given block and closes the connection again.
  #
  #===Examples
  # db.cloned_conn do |conn|
  #   conn.q('SELCET * FROM users') do |data|
  #     print data[:name]
  #   end
  # end
  def cloned_conn(args = nil, &_block)
    clone_conn_args = args[:clone_args] || {}
    dbconn = clone_conn(clone_conn_args)

    begin
      yield(dbconn)
    ensure
      dbconn.close
    end
  end

  # Yields a query-buffer and flushes at the end of the block given.
  def q_buffer(args = {}, &block)
    Baza::QueryBuffer.new(args.merge(db: self), &block)
    nil
  end

  # Returns the last inserted ID.
  #
  #===Examples
  # id = db.last_id
  def last_id
    @driver.last_id
  end

  # Escapes a string to be safe-to-use in a query-string.
  #
  #===Examples
  # db.q("INSERT INTO users (name) VALUES ('#{db.esc('John')}')")
  def escape(string)
    @driver.escape(string)
  end

  alias_method :esc, :escape

  # Escapes the given string to be used as a column.
  def escape_column(str)
    @driver.escape_column(str)
  end

  # Escapes the given string to be used as a table.
  def escape_table(str)
    @driver.escape_table(str)
  end

  def escape_database(str)
    @driver.escape_database(str)
  end

  # Returns a string which can be used in SQL with the current driver.
  #===Examples
  # str = db.date_out(Time.now) #=> "2012-05-20 22:06:09"
  def date_out(date_obj = Datet.new, args = {})
    return @driver.date_out(date_obj, args) if @driver.respond_to?(:date_out)
    Datet.in(date_obj).dbstr(args)
  end

  # Takes a valid date-db-string and converts it into a Datet.
  #===Examples
  # db.date_in('2012-05-20 22:06:09') #=> 2012-05-20 22:06:09 +0200
  def date_in(date_obj)
    return @driver.date_in(date_obj) if @driver.respond_to?(:date_in)

    Datet.in(date_obj)
  end

  def databases
    require_relative "drivers/#{@opts.fetch(:type)}/databases"
    @databases ||= Baza::Driver.const_get(@type_cc).const_get(:Databases).new(db: self)
  end

  # Returns the table-module and spawns it if it isnt already spawned.
  def tables
    @tables ||= Baza::Driver.const_get(@type_cc).const_get(:Tables).new(db: self)
  end

  # Returns the columns-module and spawns it if it isnt already spawned.
  def cols
    @cols || Baza::Driver.const_get(@type_cc).const_get(:Columns).new(db: self)
  end

  # Returns the index-module and spawns it if it isnt already spawned.
  def indexes
    @indexes ||= Baza::Driver.const_get(@type_cc).const_get(:Indexes).new(db: self)
  end

  # Returns the SQLSpec-module and spawns it if it isnt already spawned.
  def sqlspecs
    @sqlspecs ||= Baza::Driver.const_get(@type_cc).const_get(:Sqlspecs).new(db: self)
  end

  def supports_multiple_databases?
    if @driver.respond_to?(:supports_multiple_databases?)
      @driver.supports_multiple_databases?
    else
      false
    end
  end

  def supports_type_translation?
    if @driver.respond_to?(:supports_type_translation?)
      @driver.supports_multiple_databases?
    else
      false
    end
  end

  # Beings a transaction and commits when the block ends.
  #
  #===Examples
  # db.transaction do |db|
  #   db.insert(:users, name: "John")
  #   db.insert(:users, name: "Kasper")
  # end
  def transaction(&block)
    @driver.transaction(&block)
    nil
  end

  # Optimizes all tables in the database.
  def optimize(args = nil)
    STDOUT.puts "Beginning optimization of database." if @debug || (args && args[:debug])
    tables.list do |table|
      STDOUT.puts "Optimizing table: '#{table.name}'." if @debug || (args && args[:debug])
      table.optimize
    end

    nil
  end

  def to_s
    "#<Baza::Db driver=\"#{@opts[:type]}\">"
  end

  def inspect
    to_s
  end
end
