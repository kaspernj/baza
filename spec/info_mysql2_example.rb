class Baza::InfoMysql
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
    @db.tables.list.each do |_name, table|
      table.drop
    end
  end

  def after
    @db.close
  end
end
