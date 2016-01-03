class Baza::SqlQueries::PostgresUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
  end

  def execute
    sql = ""
    sql << "do $$\n"
    sql << "BEGIN\n"
    sql << "\t#{insert_sql};\n"
    sql << "EXCEPTION WHEN unique_violation THEN\n"
    sql << "\t\t#{update_sql};\n"
    sql << "END $$;"

    @db.query(sql)
  end

private

  def insert_sql
    sql = "INSERT INTO #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} ("

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
    sql = "UPDATE #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} SET "

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
