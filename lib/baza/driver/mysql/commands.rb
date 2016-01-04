class Baza::Driver::Mysql::Commands
  def initialize(args)
    @db = args.fetch(:db)
  end

  def upsert_duplicate_key(table_name, updates, terms)
    Baza::SqlQueries::MysqlUpsertDuplicateKey.new(
      db: @db,
      table_name: table_name,
      updates: updates,
      terms: terms
    ).execute
  end

  def upsert(table_name, updates, terms, args = {})
    if args[:buffer]
      Baza::SqlQueries::NonAtomicUpsert.new(
        db: @db,
        table_name: table_name,
        buffer: args[:buffer],
        terms: terms,
        updates: updates
      ).execute
    else
      Baza::SqlQueries::MysqlUpsert.new(
        db: @db,
        table_name: table_name,
        updates: updates,
        terms: terms
      ).execute
    end
  end
end
