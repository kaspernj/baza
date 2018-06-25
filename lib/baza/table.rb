class Baza::Table
  include Comparable
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
    row = rows({id: id}, limit: 1).first
    raise Baza::Errors::RowNotFound unless row
    row
  end

  def to_param
    name
  end

  def insert(data, args = {})
    @db.insert(name, data, args)
  end

  def upsert_duplicate_key(data, terms = {}, args = {})
    @db.upsert_duplicate_key(name, data, terms, args)
  end

  def rows_count
    sql = "SELECT COUNT(*) AS count FROM #{db.quote_table(name)}"
    @db.query(sql).fetch.fetch(:count).to_i
  end

  def truncate
    @db.query("TRUNCATE #{@db.quote_table(name)}")
    self
  end

  def <=>(other)
    return false unless other.is_a?(Baza::Table)
    return false unless other.db.opts.fetch(:db) == db.opts.fetch(:db)
    other.name <=> name
  end

  def create_columns(col_arr)
    col_arr.each do |col_data|
      sql = "ALTER TABLE #{db.quote_column(name)} ADD COLUMN #{@db.columns.data_sql(col_data)};"
      @db.query(sql)
    end
  end
end
