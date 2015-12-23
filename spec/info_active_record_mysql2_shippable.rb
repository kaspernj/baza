class Baza::InfoActiveRecordMysql2
  attr_reader :db

  def self.connection
    require "active_record"

    conn_pool ||= ::ActiveRecord::Base.establish_connection(
      adapter: "mysql2",
      host: "localhost",
      database: "baza",
      username: "shippa"
    )
    conn = conn_pool.connection

    {pool: conn_pool, conn: conn}
  end

  def initialize
    data = Baza::InfoActiveRecord.connection

    @db = Baza::Db.new(
      type: :active_record,
      conn: data[:conn]
    )
  end

  def before
    @db.tables.list do |table|
      table.drop
    end
  end

  def after
    @db.close
  end
end
