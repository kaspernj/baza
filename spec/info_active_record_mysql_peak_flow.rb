class Baza::InfoActiveRecordMysql
  attr_reader :db

  def self.connection
    require "active_record"
    require "activerecord-jdbc-adapter" if RUBY_PLATFORM == "java"

    @conn_pool ||= ::ActiveRecord::Base.establish_connection(
      adapter: "mysql",
      host: "mysql",
      database: "baza",
      username: "build",
      password: "password"
    )
    @conn ||= @conn_pool.connection

    {pool: @conn_pool, conn: @conn}
  end

  def initialize(args = {})
    data = Baza::InfoActiveRecordMysql.connection
    data.fetch(:conn).reconnect!

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
