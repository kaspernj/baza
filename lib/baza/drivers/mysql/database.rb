class Baza::Driver::Mysql::Database < Baza::Database
  def save!
    rename(name) unless name.to_s == name_was
    self
  end

  def drop
    sql = "DROP DATABASE `#{@db.escape_database(name)}`"
    @db.query(sql)
    self
  end

private

  def rename(new_name)
    new_name = new_name.to_s
    @db.databases.create(name: new_name)

    tables.each do |table|
      @db.query("ALTER TABLE `#{@db.escape_database(name_was)}`.`#{@db.escape_table(table.name)}` RENAME `#{@db.escape_database(name)}`.`#{@db.escape_table(table.name)}`")
    end

    @db.query("DROP DATABASE `#{@db.escape_database(name_was)}`")

    @name = new_name
    @name_was = new_name
  end
end
