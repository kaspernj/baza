class Baza::Driver::Pg::Commands
  def initialize(args)
    @db = args.fetch(:db)
  end

  def upsert_duplicate_key(table_name, updates, terms, args = {})
    @last_insert_table_name = table_name.to_s

    Baza::SqlQueries::PostgresUpsertDuplicateKey.new({
      db: @db,
      table_name: table_name,
      updates: updates,
      terms: terms
    }.merge(args)).execute
  end

  def upsert(table_name, updates, terms, args = {})
    @last_insert_table_name = table_name.to_s

    Baza::SqlQueries::NonAtomicUpsert.new({
      db: @db,
      table_name: table_name,
      terms: terms,
      updates: updates
    }.merge(args)).execute
  end

  def last_id
    @db.query("SELECT LASTVAL() AS id").fetch.fetch(:id).to_i
  end

  def version
    @version ||= @db.query("SELECT VERSION() AS version").fetch.fetch(:version).match(/\APostgreSQL ([\d\.]+)/)[1]
  end
end
