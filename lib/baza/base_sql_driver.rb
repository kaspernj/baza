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

  alias_method :esc, :escape
  alias_method :escape_alternative, :escape

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
    rescue => e
      @db.q("ROLLBACK")
    end
  end

  # Simply inserts data into a table.
  #
  #===Examples
  # db.insert(:users, name: "John", lastname: "Doe")
  # id = db.insert(:users, {name: "John", lastname: "Doe"}, return_id: true)
  # sql = db.insert(:users, {name: "John", lastname: "Doe"}, return_sql: true) #=> "INSERT INTO `users` (`name`, `lastname`) VALUES ('John', 'Doe')"
  def insert(table_name, data, args = {})
    command = Baza::SqlQueries::GenericInsert.new(
      db: @db,
      table_name: table_name,
      data: data,
      buffer: args[:buffer],
      return_id: args[:return_id]
    )

    if args[:return_sql]
      command.to_sql
    else
      command.execute
      self
    end
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
end
