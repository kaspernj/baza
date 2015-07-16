class Baza::InfoActiveRecordSqlite3
  attr_reader :db

  def self.connection
    require "active_record"

    path = "#{Dir.tmpdir}/baza_sqlite3_test_#{Time.now.to_f.to_s.hash}_#{Random.rand}.sqlite3"
    File.unlink(path) if File.exists?(path)

    @conn_pool ||= ::ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: path
    )
    @conn ||= @conn_pool.connection

    return {pool: @conn_pool, conn: @conn}
  end

  def initialize(args = {})
    data = Baza::InfoActiveRecordSqlite3.connection

    @db = Baza::Db.new({
      type: :active_record,
      conn: data[:conn]
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
