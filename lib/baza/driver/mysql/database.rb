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

  # Creates a new table by the given name and data.
  def create_table(name, columns:, indexes: nil, return_sql: false, temp: false)
    raise "No columns was given for '#{name}'." if !columns || columns.empty?

    sql = "CREATE"
    sql << " TEMPORARY" if temp
    sql << " TABLE #{@db.quote_table(name)} ("

    first = true
    columns.each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.columns.data_sql(col_data)
    end

    if indexes && !indexes.empty?
      sql << ", "
      sql << Baza::Driver::Mysql::Table.create_indexes(
        indexes,
        db: @db,
        return_sql: true,
        create: false,
        on_table: false,
        table_name: name
      )
    end

    columns.each do |col_data|
      next unless col_data.key?(:foreign_key)

      sql << ", CONSTRAINT #{SecureRandom.hex(5)} FOREIGN KEY (#{col_data.fetch(:name)}) REFERENCES #{col_data.fetch(:foreign_key).fetch(:to).fetch(0)}(#{col_data.fetch(:foreign_key).fetch(:to).fetch(1)})"
    end

    sql << ")"

    puts "SQL: #{sql}"

    sql = Baza::Driver::Mysql::Sql::CreateTable.new(
      columns: columns,
      indexes: indexes,
      name: name,
      temporary: temp
    ).sql

    return sql if return_sql

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
