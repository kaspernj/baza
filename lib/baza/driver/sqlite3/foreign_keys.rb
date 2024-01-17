class Baza::Driver::Sqlite3::ForeignKeys
  attr_reader :db

  def initialize(db:)
    @db = db
  end

  def create(name: nil, from:, to:)
    raise "Only support doing create table in SQLite"
  end
end
