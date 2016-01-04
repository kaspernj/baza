class Baza::SqlQueries::GenericInsert
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @data = args.fetch(:data)
    @buffer = args[:buffer]
  end

  def execute
    if @buffer
      @buffer.query(to_sql)
    else
      @db.query(to_sql)
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
    sql = ""

    if @db.opts.fetch(:type).to_s.include?("mysql")
      "VALUES ()" # This is the correct syntax for inserting a blank row in MySQL.
    elsif @db.opts.fetch(:type).to_s.include?("sqlite3")
      "DEFAULT VALUES"
    else
      raise "Unknown database-type: '#{@db.opts.fetch(:type)}'."
    end

    sql
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

      sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col}"
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

      sql << @db.sqlval(value)
    end

    sql << ")"
    sql
  end
end
