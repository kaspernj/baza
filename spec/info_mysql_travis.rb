class Baza::InfoMysql
  attr_reader :db

  def initialize(args = {})
    @db = Baza::Db.new({
      type: :mysql,
      host: "localhost",
      user: "build",
      db: "baza"
    }.merge(args))
  end

  def before
    @db.tables.list(&:drop)
  end

  def after
    @db.close
  end
end
