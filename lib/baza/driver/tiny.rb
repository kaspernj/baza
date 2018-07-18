class Baza::Driver::Tiny < Baza::BaseSqlDriver
  SEPARATOR_DATABASE = "]".freeze
  SEPARATOR_TABLE = "]".freeze
  SEPARATOR_COLUMN = "]".freeze
  SEPARATOR_INDEX = "]".freeze
  SEPARATOR_VALUE = "'".freeze

  def initialize(db)
    @sep_database = SEPARATOR_DATABASE
    @sep_table = SEPARATOR_TABLE
    @sep_col = SEPARATOR_COLUMN
    @sep_val = SEPARATOR_VALUE
    @sep_index = SEPARATOR_INDEX

    super

    @client = TinyTds::Client.new(username: db.opts.fetch(:user), password: db.opts.fetch(:pass), host: db.opts.fetch(:host))
  end

  def close
    @client.close
  end

  def escape(value)
    @client.escape(value)
  end

  def self.escape_identifier(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.include?("[") || string.include?("]")
    string
  end

  def self.escape_database(name)
    escape_identifier(name)
  end

  def self.escape_column(name)
    escape_identifier(name)
  end

  def self.escape_index(name)
    escape_identifier(name)
  end

  def self.escape_table(name)
    escape_identifier(name)
  end

  def escape_database(name)
    self.class.escape_identifier(name)
  end

  def escape_column(name)
    self.class.escape_identifier(name)
  end

  def escape_index(name)
    self.class.escape_identifier(name)
  end

  def escape_table(name)
    self.class.escape_identifier(name)
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
    Baza::Driver::Tiny::Result.new(@client.execute(sql))
  end

  def self.quote_identifier(name)
    "[#{escape_database(name)}]"
  end

  def self.quote_database(database_name)
    quote_identifier(database_name)
  end

  def self.quote_column(column_name)
    quote_identifier(column_name)
  end

  def self.quote_index(index_name)
    quote_identifier(index_name)
  end

  def self.quote_table(table_name)
    quote_identifier(table_name)
  end

  def quote_database(database_name)
    self.class.quote_identifier(database_name)
  end

  def quote_column(column_name)
    self.class.quote_identifier(column_name)
  end

  def quote_index(index_name)
    self.class.quote_identifier(index_name)
  end

  def quote_table(table_name)
    self.class.quote_identifier(table_name)
  end
end
