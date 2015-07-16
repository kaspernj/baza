class Baza::InfoActiveRecordMysql
  attr_reader :db

  def self.connection
    require "active_record"

    conn_pool = ::ActiveRecord::Base.establish_connection(
      adapter: "mysql",
      host: "localhost",
      database: "baza-test",
      username: "baza-test",
      password: "BBH7djRUKzL5nmG3"
    )
    conn = conn_pool.connection

    return {pool: conn_pool, conn: conn}
  end

  def initialize(args = {})
    @data = Baza::InfoActiveRecordMysql.connection

    @db = Baza::Db.new({
      type: :active_record,
      conn: @data[:conn]
    }.merge(args))
  end

  def before
    @db.tables.list.each do |name, table|
      table.drop
    end
  end

  def after
    @db.close
  end
end
