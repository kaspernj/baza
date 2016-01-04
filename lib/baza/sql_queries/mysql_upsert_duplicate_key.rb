class Baza::SqlQueries::MysqlUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
  end

  def execute
    sql = insert_sql
    sql << " ON DUPLICATE KEY UPDATE "

    first = true
    @updates.each do |key, value|
      sql << ", " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    @db.query(sql)
  end

private

  def insert_sql
    @db.insert(@table_name, @updates.merge(@terms), return_sql: true)
  end
end