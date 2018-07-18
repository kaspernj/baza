class Baza::SqlQueries::MysqlUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = StringCases.stringify_keys(args.fetch(:updates))
    @terms = StringCases.stringify_keys(args.fetch(:terms))
    @buffer = args[:buffer]
    @return_id = args[:return_id]
  end

  def to_sql
    sql = insert_sql
    sql << " ON DUPLICATE KEY UPDATE"

    first = true

    if @return_id
      sql << " #{@db.quote_column(primary_key_column_name)} = LAST_INSERT_ID(#{@db.quote_column(primary_key_column_name)})"
      first = false
    end

    @updates.each do |key, value|
      sql << "," unless first
      first = false if first
      sql << " #{@db.quote_column(key)} = #{@db.quote_value(value)}"
    end

    sql
  end

  def execute
    if @buffer
      @buffer.query(to_sql)
    else
      @db.query(to_sql)
      return @db.query(last_insert_sql).fetch.fetch(:id).to_i if @return_id
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
    "SELECT LAST_INSERT_ID() AS #{@db.quote_column("id")} FROM #{@db.quote_table(@table_name)}"
  end
end
