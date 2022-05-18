class Baza::InfoActiveRecord
  attr_reader :db

  def self.connection
    require "active_record"

    @conn_pool ||= ::ActiveRecord::Base.establish_connection(
      adapter: "mysql2",
      host: "localhost",
      database: "baza-test",
      username: "baza-test",
      password: "password"
    )
    @conn ||= @conn_pool.connection

    {pool: @conn_pool, conn: @conn}
  end

  def initialize
    data = Baza::InfoActiveRecord.connection

    @db = Baza::Db.new({
      type: :active_record,
      conn: data.fetch(:conn)
    }.merge(args))
  end

  def before
    @db.query("SET FOREIGN_KEY_CHECKS=0")
    @db.tables.list(&:drop)
    @db.query("SET FOREIGN_KEY_CHECKS=1")
  end

  def after
    @db.close
  end
end
