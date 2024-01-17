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
  include SimpleDelegate

  delegate :last_id, :upsert, :upsert_duplicate_key, to: :commands
  delegate :current_database, :current_database_name, :with_database, to: :databases
  delegate *%i[close count delete esc escape escape_column escape_table escape_database escape_index quote_database quote_column quote_table quote_value quote_database quote_index insert select single quote_value sql_make_where], to: :driver

  attr_reader :sep_database, :sep_col, :sep_table, :sep_val, :sep_index, :opts, :driver, :int_types

  # Returns an array containing hashes of information about each registered driver.
  def self.drivers
    path = "#{File.dirname(__FILE__)}/driver"
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
    @sep_database = @driver.sep_database
    @sep_table = @driver.sep_table
    @sep_col = @driver.sep_col
    @sep_index = @driver.sep_index
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
    rpath = "#{File.dirname(__FILE__)}/driver/#{@opts.fetch(:type)}.rb"
    require rpath if File.exist?(rpath)
    Baza::Driver.const_get(@type_cc).new(self)
  end

  # Registers a driver to the current thread.
  def register_thread
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

  def closed?
    @closed
  end

  # Clones the current database-connection with possible extra arguments.
  def clone_conn(args = {})
    conn = Baza::Db.new(@opts.merge(args))

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

  COPY_TO_ALLOWED_ARGS = [:tables, :debug].freeze
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
      db.tables.create(table_name, **table)

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

  def add_sql_to_error(error, sql)
    error.message << " (SQL: #{sql})"
  end

  # Simply and optimal insert multiple rows into a table in a single query. Uses the drivers functionality if supported or inserts each row manually.
  #
  #===Examples
  # db.insert_multi(:users, [
  #   {name: "John", lastname: "Doe"},
  #   {name: "Kasper", lastname: "Johansen"}
  # ])
  def insert_multi(tablename, arr_hashes, args = {})
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
  def update(table_name, data, terms = {}, args = {})
    command = Baza::SqlQueries::GenericUpdate.new(
      db: self,
      table_name: table_name,
      data: data,
      terms: terms,
      buffer: args[:buffer]
    )

    if args[:return_sql]
      command.to_sql
    else
      command.execute
    end
  end

  def in_transaction?
    @in_transaction
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

      if @debug.class.name == "Fixnum" && @debug >= 2
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
  def query_ubuf(string, _args = nil, &block)
    ret = @driver.query_ubuf(string)

    if block
      ret.each(&block)
      return nil
    end

    ret
  end

  # Yields a query-buffer and flushes at the end of the block given.
  def q_buffer(args = {}, &block)
    Baza::QueryBuffer.new(args.merge(db: self), &block)
    nil
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

  # Defines all the driver methods: tables, columns and so on
  DRIVER_PARTS = [:databases, :foreign_keys, :tables, :commands, :columns, :indexes, :users, :sqlspecs].freeze
  DRIVER_PARTS.each do |driver_part|
    define_method(driver_part) do
      if instance_variable_defined?(:"@#{driver_part}")
        instance_variable_get(:"@#{driver_part}")
      else
        require_relative "driver/#{@opts.fetch(:type)}/#{driver_part}"

        instance = Baza::Driver.const_get(@type_cc).const_get(StringCases.snake_to_camel(driver_part)).new(db: self)
        instance_variable_set(:"@#{driver_part}", instance)
        instance
      end
    end
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
    @in_transaction = true
    begin
      @driver.transaction(&block)
    ensure
      @in_transaction = false
    end

    self
  end

  # Optimizes all tables in the database.
  def optimize(args = nil)
    STDOUT.puts "Beginning optimization of database." if @debug || (args && args[:debug])
    tables.list do |table|
      STDOUT.puts "Optimizing table: '#{table.name}'." if @debug || (args && args[:debug])
      table.optimize
    end

    self
  end

  def to_s
    "#<Baza::Db driver=\"#{@opts.fetch(:type)}\">"
  end

  def inspect
    to_s
  end

  def new_query
    Baza::SqlQueries::Select.new(db: self)
  end

  def sqlite?
    @driver.class.name.downcase.include?("sqlite")
  end

  def mysql?
    @driver.class.name.downcase.include?("mysql")
  end

  def mssql?
    @driver.class.name.downcase.include?("tiny")
  end

  def postgres?
    @driver.class.name.downcase.include?("pg")
  end
end
