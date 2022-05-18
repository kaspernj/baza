class Baza::InfoMysql
  attr_reader :db

  def initialize(args = {})
    @db = Baza::Db.new({
      type: :mysql,
      host: "mysql",
      user: "build",
      pass: "password",
      db: "baza"
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
