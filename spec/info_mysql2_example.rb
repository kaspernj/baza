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
    @db.tables.list(&:drop)
  end

  def after
    @db.close
  end
end
