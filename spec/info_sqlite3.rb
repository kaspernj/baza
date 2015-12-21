class Baza::InfoSqlite3
  attr_reader :db

  def initialize(args = {})
    require "sqlite3" unless RUBY_ENGINE == "jruby"
    require "tmpdir"

    @path = "#{Dir.tmpdir}/baza_sqlite3_test_#{Time.now.to_f.to_s.hash}_#{Random.rand}.sqlite3"
    File.unlink(path) if File.exist?(@path)

    @db = Baza::Db.new({
      type: :sqlite3,
      path: @path,
      index_append_table_name: true,
      sql_to_error: true
    }.merge(args))
  end

  def before
    @db.tables.list.each do |_name, table|
      table.drop
    end
  end

  def after
    @db.close
    File.unlink(@path)
  end
end
