class Baza::BaseSqlDriver
  attr_reader :baza, :conn, :sep_table, :sep_col, :sep_val
  attr_accessor :tables, :cols, :indexes

  def self.from_object(_args)
  end

  def initialize(baza)
    @baza = baza

    @sep_table = "`"
    @sep_col = "`"
    @sep_val = "'"
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

  alias_method :esc, :escape
  alias_method :escape_alternative, :escape

  # Escapes a string to be used as a column.
  def escape_column(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" unless string.index(@sep_col).nil?
    string
  end
  alias escape_table escape_column
  alias escape_database escape_column

  def transaction
    @baza.q("BEGIN TRANSACTION")

    begin
      yield @baza
      @baza.q("COMMIT")
    rescue => e
      @baza.q("ROLLBACK")
    end
  end

  # Simply inserts data into a table.
  #
  #===Examples
  # db.insert(:users, name: "John", lastname: "Doe")
  # id = db.insert(:users, {name: "John", lastname: "Doe"}, return_id: true)
  # sql = db.insert(:users, {name: "John", lastname: "Doe"}, return_sql: true) #=> "INSERT INTO `users` (`name`, `lastname`) VALUES ('John', 'Doe')"
  def insert(tablename, arr_insert, args = nil)
    sql = "INSERT INTO #{@sep_table}#{escape_table(tablename)}#{@sep_table}"

    if !arr_insert || arr_insert.empty?
      # This is the correct syntax for inserting a blank row in MySQL.
      if @baza.opts.fetch(:type).to_s.include?("mysql")
        sql << " VALUES ()"
      elsif @baza.opts.fetch(:type).to_s.include?("sqlite3")
        sql << " DEFAULT VALUES"
      else
        raise "Unknown database-type: '#{@baza.opts.fetch(:type)}'."
      end
    else
      sql << " ("

      first = true
      arr_insert.each_key do |key|
        if first
          first = false
        else
          sql << ", "
        end

        sql << "#{@baza.sep_col}#{@baza.escape_column(key)}#{@baza.sep_col}"
      end

      sql << ") VALUES ("

      first = true
      arr_insert.each_value do |value|
        if first
          first = false
        else
          sql << ", "
        end

        sql << @baza.sqlval(value)
      end

      sql << ")"
    end

    return sql if args && args[:return_sql]

    @baza.query(sql)
    return @baza.last_id if args && args[:return_id]
    nil
  end

  def insert_multi(tablename, arr_hashes, args = nil)
    sql = [] if args && args[:return_sql]

    @baza.transaction do
      arr_hashes.each do |hash|
        res = @baza.insert(tablename, hash, args)
        sql << res if args && args[:return_sql]
      end
    end

    return sql if args && args[:return_sql]
    nil
  end

  def supports_multiple_databases?
    false
  end
end
