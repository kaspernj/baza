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
end
