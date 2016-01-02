class Baza::InfoActiveRecordMysql
  attr_reader :db

  def self.connection
    require "active_record"
    require "activerecord-jdbc-adapter" if RUBY_PLATFORM == "java"

    @conn_pool ||= ::ActiveRecord::Base.establish_connection(
      adapter: "mysql",
      host: "localhost",
      database: "baza-test",
      username: "baza-test",
      password: "password"
    )
    @conn ||= @conn_pool.connection

    {pool: @conn_pool, conn: @conn}
  end

  def initialize(args = {})
    @data = Baza::InfoActiveRecordMysql.connection
    @data.fetch(:conn).reconnect!

    @db = Baza::Db.new({
      type: :active_record,
      conn: @data.fetch(:conn)
    }.merge(args))
  end

  def before
    @db.tables.list(&:drop)
  end

  def after
    @db.close
  end
end
