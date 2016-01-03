class Baza::SqlQueries::SqliteUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
  end

  def execute
    @db.transaction do
      @db.query(insert_sql)
      @db.query(update_sql)
    end
  end

private

  def insert_sql
    sql = "INSERT OR IGNORE INTO #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} ("

    combined_data = @updates.merge(@terms)

    first = true
    combined_data.each_key do |column_name|
      sql << ", " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(column_name)}#{@db.sep_col}"
    end

    sql << ") VALUES ("

    first = true
    combined_data.each_value do |value|
      sql << ", " unless first
      first = false if first
      sql << @db.sqlval(value).to_s
    end

    sql << ")"
    sql
  end

  def update_sql
    sql = "UPDATE OR IGNORE #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} SET "

    first = true
    @updates.each do |key, value|
      sql << ", " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql << " WHERE "

    first = true
    @terms.each do |key, value|
      sql << " AND " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql
  end
end
