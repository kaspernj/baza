class Baza::InfoActiveRecordSqlite3
  attr_reader :db

  RUBY_V_3_OR_MORE = RUBY_VERSION.split(".").first.to_i >= 3

  def self.connection
    require "active_record"

    if RUBY_V_3_OR_MORE
      conn_pool = ::ActiveRecord::ConnectionAdapters::ConnectionHandler.new.establish_connection({
        adapter: "sqlite3",
        database: ":memory:"
      })
    else
      conn_pool = ::ActiveRecord::ConnectionAdapters::ConnectionHandler.new.establish_connection(
        adapter: "sqlite3",
        database: ":memory:"
      )
    end
    conn = conn_pool.connection

    {pool: conn_pool, conn: conn}
  end

  def initialize(args = {})
    data = Baza::InfoActiveRecordSqlite3.connection

    @db = Baza::Db.new({
      type: :active_record,
      conn: data.fetch(:conn),
      index_append_table_name: true
    }.merge(args))
  end

  def before; end

  def after; end
end
