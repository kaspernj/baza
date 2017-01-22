class Baza::ForeignKey
  include Baza::DatabaseModelFunctionality

  attr_reader :column_name, :db, :name, :table_name

  def column
    table.column(column_name)
  end

  def table
    @table ||= db.tables[table_name]
  end

  def to_param
    name
  end
end
