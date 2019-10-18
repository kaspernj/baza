class Baza::InfoSqlite3
  attr_reader :db

  def initialize(args = {})
    require "sqlite3" unless RUBY_ENGINE == "jruby"

    @db = Baza::Db.new({
      type: :sqlite3,
      path: "#{Dir.tmpdir}/#{SecureRandom.hex(8)}.sqlite3",
      index_append_table_name: true,
      sql_to_error: true,
      debug: false
    }.merge(args))
  end

  def before; end

  def after; end
end
