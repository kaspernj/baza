class Baza::InfoMysql2
  attr_reader :db

  def initialize(args = {})
    @db = Baza::Db.new({
      type: :mysql2,
      host: "localhost",
      user: "baza-test",
      pass: "password",
      db: "baza-test"
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
