class Baza::ForeignKey
  include Baza::DatabaseModelFunctionality

  attr_reader :column_name, :db, :name, :table_name, :referenced_column_name, :referenced_table_name

  def column
    @_column ||= table.column(column_name)
  end

  def table
    @_table ||= db.tables[table_name]
  end

  def to_param
    name
  end
end
