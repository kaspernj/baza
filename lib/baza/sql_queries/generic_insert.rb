class Baza::SqlQueries::GenericInsert
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @data = args.fetch(:data)
    @buffer = args[:buffer]
    @return_sql = args[:return_sql]
    @return_id = args[:return_id]
    @replace_line_breaks = args[:replace_line_breaks]
  end

  def execute
    if @return_sql
      to_sql
    elsif @buffer
      @buffer.query(to_sql)
    else
      @db.query(to_sql)
      @db.last_id if @return_id
    end
  end

  def to_sql
    sql = "INSERT INTO #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table}"

    if !@data || @data.empty?
      sql << " #{sql_default_values}"
    else
      sql << " #{sql_columns} VALUES #{sql_values}"
    end

    sql
  end

private

  def sql_default_values
    if @db.opts.fetch(:type).to_s.include?("mysql")
      "VALUES ()" # This is the correct syntax for inserting a blank row in MySQL.
    elsif @db.opts.fetch(:type).to_s.include?("sqlite3")
      "DEFAULT VALUES"
    else
      raise "Unknown database-type: '#{@db.opts.fetch(:type)}'."
    end
  end

  def sql_columns
    sql = "("

    first = true
    @data.each_key do |key|
      if first
        first = false
      else
        sql << ", "
      end

      sql << @db.quote_column(key)
    end

    sql << ")"
    sql
  end

  def sql_values
    sql = "("

    first = true
    @data.each_value do |value|
      if first
        first = false
      else
        sql << ", "
      end

      quoted = @db.quote_value(value)
      quoted = convert_line_breaks(quoted) if @replace_line_breaks

      sql << quoted
    end

    sql << ")"
    sql
  end

  def convert_line_breaks(quoted)
    return quoted unless quoted.include?("\n")

    if @db.postgres?
      quoted.gsub("\n", "' || CHR(10) || '")
    else
      "CONCAT(#{quoted.gsub("\n", "', CHR(10), '")}"
    end
  end
end
