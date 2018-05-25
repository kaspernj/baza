class Baza::BaseSqlDriver
  attr_reader :db, :conn, :sep_database, :sep_table, :sep_col, :sep_val, :sep_index
  attr_accessor :tables, :cols, :indexes

  SEPARATOR_DATABASE = "`".freeze
  SEPARATOR_TABLE = "`".freeze
  SEPARATOR_COLUMN = "`".freeze
  SEPARATOR_VALUE = "'".freeze
  SEPARATOR_INDEX = "`".freeze

  def self.from_object(_args); end

  def initialize(db)
    @db = db

    @sep_database = SEPARATOR_DATABASE
    @sep_table = SEPARATOR_TABLE
    @sep_col = SEPARATOR_COLUMN
    @sep_val = SEPARATOR_VALUE
    @sep_index = SEPARATOR_INDEX
  end

  def foreign_key_support?
    true
  end

  def self.escape(string)
    string.to_s.gsub(/([\0\n\r\032\'\"\\])/) do
      case Regexp.last_match(1)
      when "\0" then "\\0"
      when "\n" then "\\n"
      when "\r" then "\\r"
      when "\032" then "\\Z"
      else "\\#{Regexp.last_match(1)}"
      end
    end
  end

  def escape(string)
    self.class.escape(string)
  end

  alias esc escape
  alias escape_alternative escape

  # Escapes a string to be used as a column.
  def self.escape_column(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(SEPARATOR_COLUMN)
    string
  end

  def escape_column(string)
    self.class.escape_column(string)
  end

  def self.escape_table(string)
    string = string.to_s
    raise "Invalid table-string: #{string}" if string.include?(SEPARATOR_TABLE)
    string
  end

  def escape_table(string)
    self.class.escape_table(string)
  end

  def self.escape_database(string)
    string = string.to_s
    raise "Invalid database-string: #{string}" if string.include?(SEPARATOR_DATABASE)
    string
  end

  def escape_database(string)
    self.class.escape_database(string)
  end

  def self.escape_index(string)
    string = string.to_s
    raise "Invalid index-string: #{string}" if string.include?(SEPARATOR_INDEX)
    string
  end

  def escape_index(string)
    self.class.escape_index(string)
  end

  def transaction
    @db.q("BEGIN TRANSACTION")

    begin
      yield @db
      @db.q("COMMIT")
    rescue
      @db.q("ROLLBACK")
      raise
    end
  end

  # Simply inserts data into a table.
  #
  #===Examples
  # db.insert(:users, name: "John", lastname: "Doe")
  # id = db.insert(:users, {name: "John", lastname: "Doe"}, return_id: true)
  # sql = db.insert(:users, {name: "John", lastname: "Doe"}, return_sql: true) #=> "INSERT INTO `users` (`name`, `lastname`) VALUES ('John', 'Doe')"
  def insert(table_name, data, args = {})
    Baza::SqlQueries::GenericInsert.new({
      db: @db,
      table_name: table_name,
      data: data
    }.merge(args)).execute
  end

  def insert_multi(tablename, arr_hashes, args = {})
    sql = [] if args && args[:return_sql]

    if args && args[:return_sql]
      arr_hashes.each do |hash|
        sql << @db.insert(tablename, hash, args)
      end
    else
      @db.transaction do
        arr_hashes.each do |hash|
          @db.insert(tablename, hash, args)
        end
      end
    end

    return sql if args && args[:return_sql]
    nil
  end

  def supports_multiple_databases?
    false
  end

  SELECT_ARGS_ALLOWED_KEYS = [:limit, :limit_from, :limit_to].freeze
  # Makes a select from the given arguments: table-name, where-terms and other arguments as limits and orders. Also takes a block to avoid raping of memory.
  def select(table_name, terms = nil, args = nil, &block)
    Baza::Commands::Select.new(
      args: args,
      block: block,
      db: @db,
      table_name: table_name,
      terms: terms
    ).execute
  end

  def count(tablename, arr_terms = nil)
    sql = "SELECT COUNT(*) AS count FROM #{@sep_table}#{tablename}#{@sep_table}"

    if !arr_terms.nil? && !arr_terms.empty?
      sql << " WHERE #{sql_make_where(arr_terms)}"
    end

    query(sql).fetch.fetch(:count).to_i
  end

  # Returns a single row from a database.
  #
  #===Examples
  # row = db.single(:users, lastname: "Doe")
  def single(tablename, terms = nil, args = {})
    # Experienced very weird memory leak if this was not done by block. Maybe bug in Ruby 1.9.2? - knj
    select(tablename, terms, args.merge(limit: 1)).fetch
  end

  # Deletes rows from the database.
  #
  #===Examples
  # db.delete(:users, {lastname: "Doe"})
  def delete(tablename, arr_terms, args = nil)
    sql = "DELETE FROM #{@sep_table}#{tablename}#{@sep_table}"

    if !arr_terms.nil? && !arr_terms.empty?
      sql << " WHERE #{sql_make_where(arr_terms)}"
    end

    return sql if args && args[:return_sql]

    query(sql)
    nil
  end

  # Internally used to generate SQL.
  #
  #===Examples
  # sql = db.sql_make_where({lastname: "Doe"}, driver_obj)
  def sql_make_where(arr_terms, _driver = nil)
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

  # Returns the correct SQL-value for the given value.
  # If it is a number, then just the raw number as a string will be returned.
  # nil's will be NULL and strings will have quotes and will be escaped.
  def self.sqlval(val)
    if val.class.name == "Fixnum" || val.is_a?(Integer)
      val.to_s
    elsif val == nil
      "NULL"
    elsif val.is_a?(Date)
      "#{SEPARATOR_VALUE}#{Datet.in(val).dbstr(time: false)}#{SEPARATOR_VALUE}"
    elsif val.is_a?(Time) || val.is_a?(DateTime) || val.is_a?(Datet)
      "#{SEPARATOR_VALUE}#{Datet.in(val).dbstr}#{SEPARATOR_VALUE}"
    else
      "#{SEPARATOR_VALUE}#{escape(val)}#{SEPARATOR_VALUE}"
    end
  end

  def sqlval(val)
    return @conn.sqlval(val) if @conn.respond_to?(:sqlval)

    if val.class.name == "Fixnum" || val.is_a?(Integer)
      val.to_s
    elsif val == nil
      "NULL"
    elsif val.is_a?(Date)
      "#{@sep_val}#{Datet.in(val).dbstr(time: false)}#{@sep_val}"
    elsif val.is_a?(Time) || val.is_a?(DateTime) || val.is_a?(Datet)
      "#{@sep_val}#{Datet.in(val).dbstr}#{@sep_val}"
    else
      "#{@sep_val}#{escape(val)}#{@sep_val}"
    end
  end
end
