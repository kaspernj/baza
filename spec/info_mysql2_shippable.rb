class Baza::InfoMysql2
  attr_reader :db

  def initialize
    @db = Baza::Db.new(
      type: :mysql2,
      host: "localhost",
      user: "shippa",
      db: "baza"
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
