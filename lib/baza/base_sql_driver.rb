class Baza::BaseSqlDriver
  attr_reader :baza, :conn, :sep_table, :sep_col, :sep_val
  attr_accessor :tables, :cols, :indexes

  def self.from_object(args)
  end

  def initialize(baza)
    @baza = baza

    @sep_table = "`"
    @sep_col = "`"
    @sep_val = "'"
  end

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

  alias esc escape
  alias escape_alternative escape

  #Escapes a string to be used as a column.
  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.index(@sep_col) != nil
    return string
  end

  alias esc_table esc_col

  def transaction
    query("BEGIN TRANSACTION")

    begin
      yield @baza
      query("COMMIT")
    rescue => e
      query("ROLLBACK")
    end
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
    return nil
  end
end
