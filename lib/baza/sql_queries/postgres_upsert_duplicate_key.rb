class Baza::SqlQueries::PostgresUpsertDuplicateKey
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = StringCases.stringify_keys(args.fetch(:updates))
    @terms = StringCases.stringify_keys(args.fetch(:terms))
    @return_id = args[:return_id]
  end

  def execute
    if @db.commands.version.to_f >= 9.5 && @db.commands.version.to_f <= 9.5
      @db.query(on_conflict_sql)
    elsif @terms.empty?
      return insert_and_register_conflict
    else
      @db.query(begin_update_exception_sql)
    end

    @db.last_id if @return_id
  end

private

  def insert_and_register_conflict
    @db.query(insert_sql)
    @db.last_id if @return_id
  rescue => e
    if (match = e.message.match(/Key \((.+)\)=\((.+)\) already exists/))
      column_name = match[1]
      conflicting_value = match[2]

      @terms = {column_name => conflicting_value}
      @db.query(begin_update_exception_sql)

      if @return_id
        primary_column = table.columns.find(&:primarykey?).name.to_sym
        data = @db.single(@table_name, column_name => conflicting_value)
        return data.fetch(primary_column).to_i
      end
    else
      raise e
    end
  end

  def begin_update_exception_sql
    sql = "do $$\n"
    sql << "BEGIN\n"
    sql << "\t#{insert_sql};\n"
    sql << "EXCEPTION WHEN unique_violation THEN\n"
    sql << "\t#{update_sql};\n"
    sql << "END $$;"

    sql
  end

  def on_conflict_sql
    "#{insert_sql} ON CONFLICT (#{conflict_column_sql}) DO UPDATE #{update_set_sql}"
  end

  def conflict_column_sql
    sql = ""

    first = true
    @updates.keys.each do |column_name|
      sql << ", " if first
      first = false if first

      sql << "'#{@db.escape_column(column_name)}'"
    end

    sql
  end

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
    "UPDATE #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} #{update_set_sql} #{update_where_sql}"
  end

  def update_set_sql
    sql = "SET "

    first = true
    @updates.each do |key, value|
      sql << ", " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql
  end

  def update_where_sql
    sql = "WHERE "

    first = true
    @terms.each do |key, value|
      sql << " AND " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql
  end

  def table
    @table ||= @db.tables[@table_name.to_s]
  end
end
