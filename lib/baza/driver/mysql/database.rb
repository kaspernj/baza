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

    sql = Baza::Driver::Mysql::Sql::CreateTable
      .new(
        columns: columns,
        indexes: indexes,
        name: name,
        temporary: temp
      )
      .sql

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
