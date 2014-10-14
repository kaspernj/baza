class Baza::InfoSqlite3
  attr_reader :db

  def initialize
    require "sqlite3"
    require "tmpdir"

    @path = "#{Dir.tmpdir}/baza_sqlite3_test_#{Time.now.to_f.to_s.hash}.sqlite3"
    File.unlink(path) if File.exists?(@path)
    @db = Baza::Db.new(
      type: :sqlite3,
      path: @path,
      index_append_table_name: true,
      sql_to_error: true
    )
  end

  def before
  end

  def after
    @db.close
    File.unlink(@path)
  end
end
