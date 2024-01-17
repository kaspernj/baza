class Baza::Driver::Sqlite3::ForeignKey < Baza::ForeignKey
  def initialize(db:, data:)
    @db = db
    @column_name = data.fetch(:from)
    @name = data.fetch(:id)
    @table_name = data.fetch(:table)
    @referenced_table_name = data.fetch(:referenced_table)
    @referenced_column_name = data.fetch(:to)
  end

  def drop
    raise "stub"
  end
end
