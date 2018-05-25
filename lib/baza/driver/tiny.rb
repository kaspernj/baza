class Baza::Driver::Tiny < Baza::BaseSqlDriver
  SEPARATOR_DATABASE = "`".freeze
  SEPARATOR_TABLE = "".freeze
  SEPARATOR_COLUMN = "".freeze
  SEPARATOR_VALUE = "'".freeze
  SEPARATOR_INDEX = "`".freeze

  def initialize(db)
    super

    @sep_database = SEPARATOR_DATABASE
    @sep_table = SEPARATOR_TABLE
    @sep_col = SEPARATOR_COLUMN
    @sep_val = SEPARATOR_VALUE
    @sep_index = SEPARATOR_INDEX

    @client = TinyTds::Client.new(username: db.opts.fetch(:user), password: db.opts.fetch(:pass), host: db.opts.fetch(:host))
  end

  def close
    @client.close
  end

  def insert(table_name, data, args = {})
    sql = Baza::SqlQueries::GenericInsert.new({
      db: @db,
      table_name: table_name,
      data: data
    }.merge(args)).to_sql

    result = @client.execute(sql)
    result.insert if args[:return_id]
  end

  def query(sql)
    result = @client.execute(sql)
    Baza::Driver::Tiny::Result.new(result)
  end
end
