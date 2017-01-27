class Baza::Driver::Sqlite3::Database < Baza::Database
  def use
    # Dont do anything since the file only contains one database
  end
end
