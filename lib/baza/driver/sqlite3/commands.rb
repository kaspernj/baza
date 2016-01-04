class Baza::Driver::Sqlite3::Commands
  def initialize(args)
    @db = args.fetch(:db)
  end

  def upsert_duplicate_key(table_name, updates, terms, args = {})
    Baza::SqlQueries::SqliteUpsertDuplicateKey.new({
      db: @db,
      table_name: table_name,
      updates: updates,
      terms: terms
    }.merge(args)).execute
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

  def last_id
    @db.query("SELECT last_insert_rowid() AS id").fetch.fetch(:id).to_i
  end
end
