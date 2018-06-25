class Baza::Driver::Mysql::Database < Baza::Database
  def save!
    rename(name) unless name.to_s == name_was
    self
  end

  def drop
    sql = "DROP DATABASE #{@db.quote_database(name)}"
    @db.query(sql)
    self
  end

  CREATE_ALLOWED_KEYS = [:columns, :indexes, :temp, :return_sql].freeze
  # Creates a new table by the given name and data.
  def create_table(name, data, args = nil)
    raise "No columns was given for '#{name}'." if !data[:columns] || data[:columns].empty?

    sql = "CREATE"
    sql << " TEMPORARY" if data[:temp]
    sql << " TABLE #{@db.quote_table(name)} ("

    first = true
    data[:columns].each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.columns.data_sql(col_data)
    end

    if data[:indexes] && !data[:indexes].empty?
      sql << ", "
      sql << Baza::Driver::Mysql::Table.create_indexes(
        data[:indexes],
        db: @db,
        return_sql: true,
        create: false,
        on_table: false,
        table_name: name
      )
    end

    sql << ")"

    # return [sql] if args && args[:return_sql]

    sql = Baza::Driver::Mysql::Sql::CreateTable.new(
      columns: data.fetch(:columns),
      indexes: data[:indexes],
      name: name,
      temporary: data[:temp]
    ).sql

    return sql if args && args[:return_sql]

    use do
      sql.each do |sql_i|
        @db.query(sql_i)
      end
    end
  end

private

  def rename(new_name)
    new_name = new_name.to_s
    @db.databases.create(name: new_name)

    tables.each do |table|
      @db.query("ALTER TABLE #{@db.quote_database(name_was)}.#{@db.quote_table(table.name)} RENAME #{@db.quote_database(name)}.#{@db.quote_table(table.name)}")
    end

    @db.query("DROP DATABASE #{@db.quote_database(name_was)}")

    @name = new_name
    @name_was = new_name
  end
end
