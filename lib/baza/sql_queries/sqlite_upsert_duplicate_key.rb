class Baza::SqlQueries::SqliteUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = StringCases.stringify_keys(args.fetch(:updates))
    @terms = StringCases.stringify_keys(args.fetch(:terms))
    @return_id = args[:return_id]
  end

  def execute
    return insert_or_handle_duplicate if @terms.empty?

    @db.transaction do
      @db.query(insert_sql)
      @db.query(update_sql)

      if @return_id
        data = @db.single(@table_name, @terms)
        raise "Couldn't find the updated data" unless data
        return data.fetch(primary_column).to_i
      end
    end
  end

private

  def primary_column
    @primary_column ||= @db.tables[@table_name.to_s].columns.find(&:primarykey?).name.to_sym
  end

  def insert_or_handle_duplicate
    @db.insert(@table_name, @updates)
    return @db.last_id if @return_id
  rescue => e
    if (match = e.message.match(/UNIQUE constraint failed: #{Regexp.escape(@table_name)}\.(.+?)(:|\Z|\))/))
      column_name = match[1]
    elsif (match = e.message.match(/column (.+?) is not unique/))
      column_name = match[1]
    else
      raise e
    end

    conflicting_value = @updates.fetch(column_name)
    @db.update(@table_name, @updates, column_name => conflicting_value)

    if @return_id
      data = @db.single(@table_name, column_name => conflicting_value)
      raise "Couldn't find the updated data" unless data
      return data.fetch(primary_column).to_i
    end
  end

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
