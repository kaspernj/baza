class Baza::BaseSqlDriver
  attr_reader :db, :conn, :sep_database, :sep_table, :sep_col, :sep_val, :sep_index
  attr_accessor :tables, :cols, :indexes

  def self.from_object(_args)
  end

  def initialize(db)
    @db = db

    @sep_database = "`"
    @sep_table = "`"
    @sep_col = "`"
    @sep_val = "'"
    @sep_index = "`"
  end

  def escape(string)
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

  alias esc escape
  alias escape_alternative escape

  # Escapes a string to be used as a column.
  def escape_column(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?(@sep_col)
    string
  end

  def escape_table(string)
    string = string.to_s
    raise "Invalid table-string: #{string}" if string.include?(@sep_table)
    string
  end

  def escape_database(string)
    string = string.to_s
    raise "Invalid database-string: #{string}" if string.include?(@sep_database)
    string
  end

  def escape_index(string)
    string = string.to_s
    raise "Invalid index-string: #{string}" if string.include?(@sep_index)
    string
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

    @db.transaction do
      arr_hashes.each do |hash|
        res = @db.insert(tablename, hash, args)
        sql << res if args && args[:return_sql]
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
  def select(tablename, arr_terms = nil, args = nil, &block)
    # Set up vars.
    sql = ""
    args_q = nil
    select_sql = "*"

    # Give 'cloned_ubuf' argument to 'q'-method.
    args_q = {cloned_ubuf: true} if args && args[:cloned_ubuf]

    # Set up IDQuery-stuff if that is given in arguments.
    if args && args[:idquery]
      if args.fetch(:idquery) == true
        select_sql = "#{sep_col}id#{sep_col}"
        col = :id
      else
        select_sql = "#{sep_col}#{escape_column(args.fetch(:idquery))}#{sep_col}"
        col = args.fetch(:idquery)
      end
    end

    sql = "SELECT #{select_sql} FROM"

    if tablename.is_a?(Array)
      sql << " #{@sep_table}#{tablename.first}#{@sep_table}.#{@sep_table}#{tablename.last}#{@sep_table}"
    else
      sql << " #{@sep_table}#{tablename}#{@sep_table}"
    end

    if !arr_terms.nil? && !arr_terms.empty?
      sql << " WHERE #{sql_make_where(arr_terms)}"
    end

    unless args.nil?
      if args[:orderby]
        sql << " ORDER BY"

        if args.fetch(:orderby).is_a?(Array)
          first = true
          args.fetch(:orderby).each do |order_by|
            sql << "," unless first
            first = false if first
            sql << " #{sep_col}#{escape_column(order_by)}#{sep_col}"
          end
        else
          sql << " #{sep_col}#{escape_column(args.fetch(:orderby))}#{sep_col}"
        end
      end

      sql << " LIMIT #{args[:limit]}" if args[:limit]

      if args[:limit_from] && args[:limit_to]
        begin
          Float(args[:limit_from])
        rescue
          raise "'limit_from' was not numeric: '#{args.fetch(:limit_from)}'."
        end

        begin
          Float(args[:limit_to])
        rescue
          raise "'limit_to' was not numeric: '#{args[:limit_to]}'."
        end

        sql << " LIMIT #{args.fetch(:limit_from)}, #{args.fetch(:limit_to)}"
      end
    end

    # Do IDQuery if given in arguments.
    if args && args[:idquery]
      res = Baza::Idquery.new(db: @db, table: tablename, query: sql, col: col, &block)
    else
      res = @db.q(sql, args_q, &block)
    end

    # Return result if a block wasnt given.
    if block
      return nil
    else
      return res
    end
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
  def sqlval(val)
    return @conn.sqlval(val) if @conn.respond_to?(:sqlval)

    if val.is_a?(Fixnum) || val.is_a?(Integer)
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
