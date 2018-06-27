class Baza::InfoActiveRecordSqlite3
  attr_reader :db

  def self.connection
    require "active_record"

    conn_pool = ::ActiveRecord::ConnectionAdapters::ConnectionHandler.new.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )
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
