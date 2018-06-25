class Baza::Driver::Pg::ForeignKey < Baza::ForeignKey
  def initialize(args)
    @db = args.fetch(:db)

    data = args.fetch(:data)

    @column_name = data.fetch(:column_name)
    @name = data.fetch(:constraint_name)
    @table_name = data.fetch(:table_name)
  end

  def drop
    @db.query("
      ALTER TABLE #{@db.quote_table(table_name)}
      DROP CONSTRAINT #{@db.quote_table(name)}
    ")
    true
  end
end
