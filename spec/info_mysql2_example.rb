class Baza::InfoMysql
  attr_reader :db

  def initialize
    @db = Baza::Db.new(
      type: :mysql2,
      host: "localhost",
      user: "baza-test",
      pass: "password",
      db: "baza-test"
    )
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
