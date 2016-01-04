class Baza::Driver::Sqlite3::Commands
  def initialize(args)
    @db = args.fetch(:db)
  end

  def upsert_duplicate_key(table_name, updates, terms)
    Baza::SqlQueries::SqliteUpsertDuplicateKey.new(
      db: @db,
      table_name: table_name,
      updates: updates,
      terms: terms
    ).execute
  end

  def upsert(table_name, updates, terms, args = {})
    Baza::SqlQueries::NonAtomicUpsert.new(
      db: @db,
      table_name: table_name,
      buffer: args[:buffer],
      terms: terms,
      updates: updates
    ).execute
  end
end
