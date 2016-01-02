class Baza::InfoPg
  attr_reader :db

  def initialize(args = {})
    @db = Baza::Db.new({
      type: :pg,
      host: "127.0.0.1",
      user: "baza-test",
      pass: "password",
      db: "baza-test",
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
