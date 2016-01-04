class Baza::SqlQueries::MysqlUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
    @buffer = args[:buffer]
    @return_id = args[:return_id]
  end

  def to_sql
    sql = insert_sql
    sql << " ON DUPLICATE KEY UPDATE"

    first = true

    if @return_id
      sql << " #{@db.sep_col}#{@db.escape_column(primary_key_column_name)}#{@db.sep_col} = LAST_INSERT_ID(#{@db.sep_col}#{@db.escape_column(primary_key_column_name)}#{@db.sep_col})"
      first = false
    end

    @updates.each do |key, value|
      sql << "," unless first
      first = false if first
      sql << " #{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql
  end

  def execute
    if @buffer
      @buffer.query(to_sql)
    else
      @db.query(to_sql)
      return @db.query(last_insert_sql).fetch.fetch(:id) if @return_id
    end
  end

private

  def insert_sql
    @db.insert(@table_name, @updates.merge(@terms), return_sql: true)
  end

  def table
    @table ||= @db.tables[@table_name.to_s]
  end

  def primary_key_column_name
    @primary_key_column_name ||= table.columns(primarykey: true).first.name
  end

  def last_insert_sql
    "SELECT LAST_INSERT_ID() AS `id` FROM #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table}"
  end
end
