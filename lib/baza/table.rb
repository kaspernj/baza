class Baza::Table
  include Baza::DatabaseModelFunctionality

  attr_reader :db

  def to_s
    "#<#{self.class.name} name=\"#{name}\">"
  end

  def inspect
    to_s
  end

  def rows(*args)
    ArrayEnumerator.new do |yielder|
      db.select(name, *args) do |data|
        yielder << Baza::Row.new(
          db: db,
          table: name,
          data: data
        )
      end
    end
  end

  def row(id)
    data = rows({id: id}, limit: 1).fetch
    raise Baza::Errors::RowNotFound unless data

    Baza::Row.new(
      db: db,
      table: name,
      data: data
    )
  end

  def to_param
    name
  end
end
