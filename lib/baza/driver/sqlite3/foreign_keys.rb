class Baza::Driver::Sqlite3::ForeignKeys
  attr_reader :db

  def initialize(db:)
    @db = db
  end

  def create(from:, to:, name: nil) # rubocop:disable Lint/UnusedMethodArgument
    raise "Only support doing create table in SQLite"
  end
end
