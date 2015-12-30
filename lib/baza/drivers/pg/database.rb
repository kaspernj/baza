class Baza::Driver::Pg::Database < Baza::Database
  def save!
    rename(name) unless name.to_s == name_was
    self
  end

  def drop
    @db.query("DROP DATABASE #{@db.sep_database}#{@db.escape_database(name)}#{@db.sep_database}")
    self
  end

private

  def rename(new_name)
    @db.query("ALTER DATABASE #{@db.sep_database}#{@db.escape_database(name_was)}#{@db.sep_database} RENAME TO #{@db.sep_database}#{@db.escape_database(new_name)}#{@db.sep_database}")
    @name = new_name.to_s
    self
  end
end
