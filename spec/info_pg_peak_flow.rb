class Baza::InfoPg
  attr_reader :db

  def initialize(args = {})
    @db = Baza::Db.new({
      type: :pg,
      host: "postgres",
      user: "build",
      pass: "password",
      db: "baza",
      debug: false
    }.merge(args))
  end

  def before
    @db.tables.list(&:drop)
  end

  def after
    @db.close
  end
end
